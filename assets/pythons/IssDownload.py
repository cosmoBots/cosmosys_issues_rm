#!/usr/bin/env python
# coding: utf-8

from cfg.config_iss import *
#from redminelib import Redmine

import sys
#print("This is the name of the script: ", sys.argv[0])
#print("Number of arguments: ", len(sys.argv))
#print("The arguments are: " , str(sys.argv))

def tree_to_dict_list(tree,parentNode):
    result = {}
    result2 = []
    result3 = []
    #print("\n\n\n******ARBOL******* len= ",len(tree))
    for node in tree:
        node['chapters'] = []
        node['issues'] = []
        #print("\n\n\n******NODO*******",node['id'])
        if (node['id']) == (node['doc_id']):
            result3.append(node)
            #print("\n\n\n******DOCUMENTO*******",node['id'])
            # Nos encontramos en un documento, vamos a "enriquecer" el nodo de Issuedocs 
            # con la información de "children" para que el generador de informes pueda 
            # partir de los documentos en forma de árbol
            data['Issuedocs'][str(node['doc_id'])]['children'] = node['children']
            data['Issuedocs'][str(node['doc_id'])]['chapters'] = []
            data['Issuedocs'][str(node['doc_id'])]['issues'] = []

        if 'type' in node.keys():
            if (node['type'] == "Info"):
                # Nos encontramos en un nodo del tipo informacion, para el que no vamos a 
                # querer, posiblemente, generar tablas de atributos.  Para que Carbone
                # pueda filtrar facilmente este tipo de datos, le anyadiremos la propiedad
                # infoType = 1.
                node['infoType'] = 1
                if (parentNode != None):
                    parentNode['chapters'].append(node)
                    if (parentNode['id'] == parentNode['doc_id']):
                        data['Issuedocs'][str(node['doc_id'])]['chapters'].append(node)
            else:
                node['infoType'] = 0
                if (parentNode != None):
                    parentNode['issues'].append(node)
                    if (parentNode['id'] == parentNode['doc_id']):
                        data['Issuedocs'][str(node['doc_id'])]['issues'].append(node)

        else:
            node['infoType'] = 0
            if (parentNode != None):
                parentNode['issues'].append(node)
                if (parentNode['id'] == parentNode['doc_id']):
                    data['Issuedocs'][str(node['doc_id'])]['issues'].append(node)


        #print(node['subject'])
        node['status'] = data['statuses'][str(node['status_id'])]
        if 'fixed_version_id' in node.keys():
            if (node['fixed_version_id'] is not None):
                node['target'] = data['targets'][str(node['fixed_version_id'])]

        node['tracker'] = data['trackers'][str(node['tracker_id'])]
        node['doc'] = data['Issuedocs'][str(node['doc_id'])]['subject']
        purgednode = node.copy()
        purgednode['children'] = []
        #print(purgednode)
        result[str(purgednode['id'])] = purgednode
        result2.append(purgednode)
        r,r2,r3 = tree_to_dict_list(node['children'],node)
        result.update(r)
        result2 += r2
        result3 += r3

    return result,result2,result3



# pr_id_str = issue_project_id_str
pr_id_str = sys.argv[1]
#print("id: ",pr_id_str)

# reporting_path = reporting_dir
download_filepath = sys.argv[2]
#print("download_filepath: ",download_filepath)

root_url = sys.argv[3]
#print("root_url: ",root_url)

tmpfilepath = None
if (len(sys.argv) > 4):
    # tmpfilepath
    tmpfilepath = sys.argv[4]
    #print("tmpfilepath: ",tmpfilepath)

if (tmpfilepath is None):
    import json,urllib.request
    urlfordata = root_url+"/cosmosys_issues/"+pr_id_str+".json?key="+issue_key_txt
    #print("urlfordata: ",urlfordata)
    datafromurl = urllib.request.urlopen(urlfordata).read().decode('utf-8')
    data = json.loads(datafromurl)

else:
    import json
    with open(tmpfilepath, 'r', encoding="utf-8") as tmpfile:
        data = json.load(tmpfile)


my_project = data['project']

#print ("Obtenemos proyecto: ", my_project['id'], " | ", my_project['name'])

Issuedocs = data['Issuedocs']
issues = data['issues']
targets = data['targets']
statuses = data['statuses']
# Ahora vamos a generar los diagramas de jerarquía y de dependencia para cada una de los issues, y los guardaremos en la carpeta doc.
#print("len(issues)",len(issues))
Issuedict,Issuelist,my_doc_issues = tree_to_dict_list(issues,None)

#print("ACABAMOS!!!!!!!!!!!!!!!!!!!!!!!!!!!")

# Conectaremos con nuestra instancia de PYOO
# https://github.com/seznam/pyoo

# In[ ]:


import pyoo
desktop = pyoo.Desktop('localhost', 2002)


# Copiamos el template del fichero de exportación al nombre de exportación

# In[ ]:


from shutil import copyfile

copyfile('./plugins/cosmosys_issues/assets/pythons/templates/IssDownload.ods', download_filepath)


# Hemos de cargar los IssTarget

# In[ ]:


# Conectamos con la hoja
doc = desktop.open_spreadsheet(download_filepath)

# La lista de IssTarget empieza en B7, hacia abajo
rq_target_column = 2
rq_target_row = 8


# In[ ]:


#print(dir(doc))
#print(len(doc.sheets))
doc_dict = doc.sheets['Dict']
#print(doc_dict)
#print(doc_dict[rq_target_row,rq_target_column].address)
#doc_dict[rq_target_row,rq_target_column].value = 5


# In[ ]:
#print("ACABAMOS2!!!!!!!!!!!!!!!!!!!!!!!!!!!")

doc_dict[issue_download_url_row,issue_download_url_column].value = root_url+'/'
rowindex = issue_download_version_startrow

#print("ACABAMOS3!!!!!!!!!!!!!!!!!!!!!!!!!!")
for v in targets:
    #print(v)
    doc_dict[rowindex,issue_download_version_column].value = targets[v]
    rowindex += 1

#print("ACABAMOS4!!!!!!!!!!!!!!!!!!!!!!!!!!!")
# Ahora generaremos los documentos a partir de los Issuedoc

# In[ ]:


tabnumber = 3
for my_issue in my_doc_issues:
    #print("********** ",my_issue['subject'])
    prefix = my_issue['prefix']
    mysheet = doc.sheets.copy('Template', my_issue['subject'], tabnumber)
    tabnumber += 1
    mysheet[issue_download_doc_row,issue_download_doc_title_column].value = my_issue['title']
    mysheet[issue_download_doc_row,issue_download_doc_desc_column].value = my_issue['description']
    mysheet[issue_download_doc_row,issue_download_doc_prefix_column].value = prefix
    current_parent = my_issue['parent_id']
    if current_parent is not None:
        parent_issue = Issuedocs[str(current_parent)]
        #print("parent: ",parent_issue.subject)
        # Rellenamos la celda del padre
        mysheet[issue_download_doc_row,issue_download_doc_parent_column].value = parent_issue['subject']
    
    current_version = my_issue['fixed_version_id']
          
# Ahora crearemos los issues "hijos" dentro de cada documento

# In[ ]:


def find_doc(this_issue):
    #print("find_doc: ",this_issue)
    if this_issue['tracker'] == 'IssueDoc':
        #print("retorno this", this_issue.subject)
        return this_issue['subject'],this_issue['prefix'] 

    # not do found yet
    current_parent = this_issue['parent_id']
    if current_parent is None:
        #print("retorno none")
        return "",""
    
    else:
        parent_issue = Issuedict[str(current_parent)]
        #print("Llamo al padre")
        return find_doc(parent_issue)
    
current_row = {}
for my_issue in my_doc_issues:
    current_row[my_issue['subject']] = issue_download_first_row
    

rpdeptab = doc.sheets["_IssDep"]
rpdeptab_row_idx = issue_download_rpdeptab_startrow

#print(current_row)
#print(len(Issuelist))
for my_issue in Issuelist:
    if my_issue['tracker'] == 'Issue':
        Issuename = my_issue['subject']
        #print("Issuename: ",Issuename)
        current_parent = my_issue['parent_id']
        if current_parent is not None:
            #print("current_parent 1: ",current_parent)
            parent_issue = Issuedict[str(current_parent)]
            if parent_issue['tracker'] != 'Issue':
                current_parent = None
            #else:
                #print("parent: ",parent_issue['subject'])
        
        thisdoc,thisprefix = find_doc(parent_issue)
        #print("thisdoc:",thisdoc)
        #print("thisprefix:",thisprefix)
        thistab = doc.sheets[thisdoc]
        currrow = current_row[thisdoc]
        #print("add the Issue to the row ",currrow," of the tab ",thistab)
        if 'target' in my_issue.keys():
            current_version = my_issue['target']
        else:
            current_version = None
        idstr = my_issue['subject'].replace(thisprefix,'')

        thistab[currrow,issue_download_id_column].value = my_issue['subject']
        thistab[currrow,issue_download_title_column].value = my_issue['title']
        descr = my_issue['description']
        if descr is None:
            descr = ""
        thistab[currrow,issue_download_descr_column].value = descr
        sources = my_issue['sources']
        #print("*********************************************** SOURCES ")
        #print(sources)
        if sources is None:
            sources = ""
        thistab[currrow,issue_download_source_column].value = sources
        typestr = my_issue['type']
        if typestr is None:
            typestr = ""
        thistab[currrow,issue_download_type_column].value = typestr
        level = my_issue['level']
        if level is None:
            level = ""
        thistab[currrow,issue_download_level_column].value = level
        rationale = my_issue['rationale']
        if rationale is None:
            rationale = ""
        thistab[currrow,issue_download_rationale_column].value = rationale
        var = my_issue['var']
        if var is None:
            var = ""
        thistab[currrow,issue_download_var_column].value = var
        value = my_issue['value']
        if value is None:
            value = ""        
        thistab[currrow,issue_download_value_column].value = value
        thistab[currrow,issue_download_chapter_column].value = my_issue['chapter'].replace(thisprefix,'')
        thistab[currrow,issue_download_status_column].value = my_issue['status']
        thistab[currrow,issue_download_bdid_column].value = my_issue['id']
        try:
            # if idstr is a number, we will ignore leading zeroes
            thistab[currrow,issue_download_rqid_column].value = int(idstr)
        except:
            # if it is not a number, we will use them as is
            thistab[currrow,issue_download_rqid_column].value = idstr
        
        if (current_version is not None):
            thistab[currrow,issue_download_target_column].value = current_version

        if current_parent is not None:
            thistab[currrow,issue_download_parent_column].value = parent_issue['subject']

            
        # Busco las relaciones en las que es destinatario
        my_filtered_issue_relations =  my_issue['relations_back']

        # Recorro las relaciones creando los links
        relstr = ""
        firstrel = True
        for rel in my_filtered_issue_relations:
            # Obtenemos la incidencia y el item doorstop del objeto que es origen de la relación de Redmine,
            # que significa que es destinatario de la relación de doorstop, ya que es el elemento que está
            # condicionando al actual (el actual depende de él)
            relissue = Issuedict[str(rel['issue_from_id'])]
            #print("Relacionado: ",rel," de ",relissue.subject," a ",my_issue.subject)
            if firstrel:
                firstrel = False
            else:
                relstr += " "
                
            relstr += relissue['subject']
            
        if not firstrel:
            thistab[currrow,issue_download_related_column].value = relstr


        current_row[thisdoc] = currrow + 1    

        if (my_issue['type'] != 'Info'):        
            rpdeptab[rpdeptab_row_idx,issue_download_rpdeptab_id_column].value = my_issue['subject']
            rpdeptab[rpdeptab_row_idx,issue_download_rpdeptab_title_column].value = my_issue['title']
            if not firstrel:
                rpdeptab[rpdeptab_row_idx,issue_download_rpdeptab_related_column].value = relstr

            rpdeptab_row_idx = rpdeptab_row_idx +1

            


doc.save()
doc.close()




