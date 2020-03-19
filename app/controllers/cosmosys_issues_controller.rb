class CosmosysIssuesController < ApplicationController
  before_action :find_project#, :authorize, :except => [:tree]

  @@chapterdigits = 3
  @@cfchapter = IssueCustomField.find_by_name('IssChapter')
  
  @@tmpdir = './tmp/cosmosys_issue_plugin/'

  def index
    @cosmosys_issues = CosmosysIssuesBase.all
  end 

  def create_repo
    if request.get? then
      #print("GET!!!!!")
    else
      #print("POST!!!!!")
      @output = ""
      # First we check if the setting for the local repo is set
      if (Setting.plugin_cosmosys_issues['repo_local_path'].blank?) then
        # If it is not set, we can not continue
        @output += "Error: the local repos path template is not defined\n"
      else
        # We need to know if the setting to locate the repo template is set
        if (Setting.plugin_cosmosys_issues['repo_template_id'].blank?) then
          @output += "Error: the template id setting is not set\n"
        else
          # The setting exists, so we can create the origin and destination paths
          destdir = "#{Setting.plugin_cosmosys_issues['repo_local_path']}"
          destdir["%project_id%"]= @project.identifier
          origdir = "#{Setting.plugin_cosmosys_issues['repo_local_path']}"
          origdir["%project_id%"]= Setting.plugin_cosmosys_issues['repo_template_id']

          # Now we have to know if the destination directory already exists
          if (File.directory?(destdir)) then
            @output += "Error: the destination repo already exists\n"  
            print(destdir)            
          else
            if (File.directory?(origdir)) then
              comando = "cp -r #{origdir} #{destdir}"
              print("\n\n #{comando}")
              `#{comando}`
              comando = "cd #{destdir}; git init"
              print("\n\n #{comando}")
              `#{comando}`
              git_commit_repo(@project,"[Issuebot] project creation")
              if (Setting.plugin_cosmosys_issues['repo_redmine_sync']) then
                # The setting says we must sync with a remote server
                if (Setting.plugin_cosmosys_issues['repo_redmine_path'].blank?) then
                  # The setting is not set, so we can not sync with the remote server
                  @output += "Error: the redmine repo path template is not defined\n"
                else
                  redminerepodir = "#{Setting.plugin_cosmosys_issues['repo_redmine_path']}"
                  redminerepodir["%project_id%"] = @project.identifier
                  #git clone --bare demo demo.git
                  comando = "git clone --mirror #{destdir} #{redminerepodir}"
                  print("\n\n #{comando}")
                  `#{comando}`
                  # Now we link the repo to the project
                  repo = Repository::Git.new
                  repo.is_default = true
                  repo.project = @project
                  repo.url = redminerepodir
                  repo.identifier = "rq"
                  repo.extra_info =  {"extra_report_last_commit"=>"1"}
                  repo.save
                end
              else
                @output += "Info: redmine sync not enabled\n"          
              end
            else
              @output += "Error: the template repo does not exist\n"
              print(origdir)
            end
          end
        end 
      end
      if @output.size <= 255 then 
          flash[:notice] = @output.to_s
      else
          flash[:notice] = "Message too long\n"
      end
      print(@output)
    end
  end

  def project_menu
  end

  def show_as_tree
    require 'json'

    splitted_url = request.fullpath.split('/cosmosys_issues')
    root_url = request.base_url+splitted_url[0]

    if request.get? then
      print("GET!!!!!")
      if (params[:node_id]) then
        print("NODO!!!\n")
        treedata = CosmosysIssuesBase.show_as_json(@project,params[:node_id],root_url)
      else
        print("PROYECTO!!!\n")
        treedata = CosmosysIssuesBase.show_as_json(@project,nil,root_url)
      end

      respond_to do |format|
        format.html {
          @to_json = treedata.to_json
        }
        format.json { 
          require 'json'
          ActiveSupport.escape_html_entities_in_json = false
          render json: treedata
          ActiveSupport.escape_html_entities_in_json = true        
        }
      end
    else
      print("POST!!!!!")
      structure = params[:structure]
      json_params_wrapper = JSON.parse(request.body.read())
      structure = json_params_wrapper['structure']
      #print ("structure: \n\n")
      #print structure
      rootnode = structure[0]
      structure.each { |n|
        CosmosysIssuesBase.update_node(n,nil,"",1)
      }
      redirect_to :action => 'tree', :method => :get, :id => @project.id 
    end
  end

  def show
    show_as_tree
  end

  def upload

    # This section defines the connection between the CosmoSys_issue tools and the OpenDocument spreadsheet used for importing issues
    issue_upload_start_column = 0
    issue_upload_end_column = 16
    issue_upload_start_row = 0
    issue_upload_end_row = 199

    #This section defines the document information cell indexes to retrieve information for the documents from the upload file
    issue_upload_doc_row = 0
    issue_upload_doc_desc_column = 6
    issue_upload_doc_parent_column = 8

    #This section defines the issues information cell indexes to retrieve information for the issues from the upload file
    issue_upload_first_row = 2
    issue_upload_column_number = issue_upload_end_column + 1
    issue_upload_subject_column = 4
    issue_upload_related_column = 10
    issue_upload_descr_column = 6
    issue_upload_chapter_column = 0
    issue_upload_target_column = 12
    issue_upload_parent_column = 7
    issue_upload_status_column = 16

    issue_upload_version_column = 5
    issue_upload_version_startrow = 1
    issue_upload_version_endrow = 25


    print("\n\n\n\n\n\n")

    my_project_versions = []
    @project.versions.each { |v| 
      my_project_versions << v
    }
    print my_project_versions

    if request.get? then
      print("GET!!!!!")
    else
      print("POST!!!!!")


      git_pull_repo(@project)
      @output = ""
      # First we check if the setting for the local repo is set
      if (Setting.plugin_cosmosys_issues['repo_local_path'].blank?) then
        # If it is not set, we can not continue
        @output += "Error: the local repos path template is not defined\n"
      else
        # The setting exists, so we can create the origin and destination paths
        repodir = "#{Setting.plugin_cosmosys_issues['repo_local_path']}"
        repodir["%project_id%"]= @project.identifier
        # Now we have to know if the destination directory already exists
        if (File.directory?(repodir)) then
          if (Setting.plugin_cosmosys_issues['relative_uploadfile_path'].blank?) then
            # If it is not set, we can not continue
            @output += "Error: the relative path to upload file is not set\n"
          else
            uploadfilepath = repodir + "/" + Setting.plugin_cosmosys_issues['relative_uploadfile_path']
            if (File.exists?(uploadfilepath)) then

              # Process Dict
              book = Rspreadsheet.open(uploadfilepath)
              dictsheet = book.worksheets('Dict')
              introsheet = book.worksheets('Intro')
              templatesheet = book.worksheets('Template')

              # Import versions
              rowindex = issue_upload_version_startrow+1
              while (rowindex <= issue_upload_version_endrow+1) do
                d = dictsheet.row(rowindex)
                rowindex += 1
                thisversion = d[issue_upload_version_column+1]
                if (thisversion!=nil) then
                  #print(rowindex.to_s + ": " + thisversion)
                  findVersionSuccess = false
                  thisVersionId = nil
                  my_project_versions.each { |v|  
                      if not(findVersionSuccess) then
                          if (v.name == thisversion) then
                              findVersionSuccess = true
                              #print("la version ",thisversion," ya existe")
                          end
                      end
                  }
                  if not findVersionSuccess then
                      #print("la version " + thisversion + " no existe")
                      nv = @project.versions.new
                      nv.name = thisversion
                      nv.status = 'open'
                      nv.sharing = 'hierarchy'
                      nv.description = thisversion
                      nv.save
                      my_project_versions << nv
                      #print("\nhe creado la version " + nv.name + "con id " + nv.id.to_s)
                  end
                end
              end

              sheetindex = 1
              thissheet = book.worksheets(sheetindex)

# Ya tenemos los documentos de Issues (pestañas) cargados como Issues padres.  Ahora puedo recorrer los Issues de cada una de las pestañas y crear los Issues que falten.

# In[ ]:

              status_dict = {}
              IssueStatus.all.each{|st|
                  status_dict[st.name] = st.id
              }
              sheetindex = 1
              thissheet = book.worksheets(sheetindex)
              while (thissheet != nil) do
                docidstr = thissheet.name
                if ((docidstr[0] != '_') and (thissheet != dictsheet) and (thissheet != introsheet) and (thissheet != templatesheet)) then
                  # Tratamos la hoja en concreto
                  current_row = issue_upload_first_row+1
                  while (current_row <= issue_upload_end_row) do
                    r = thissheet.row(current_row)
                    #print("\nTrato la fila "+ current_row.to_s)
                    #print("title: ",title_str)
                    # Estamos procesando las lineas de Issues
                    issuesubjstr = r[issue_upload_subject_column+1]
                    #print("rqid: "+issuesubjstr)
                    descr = r[issue_upload_descr_column+1]
                    rqchapterstr = r[issue_upload_chapter_column+1].to_s
                    rqchapterarray = rqchapterstr.split('.')
                    #print(rqchapterarray)
                    rqchapterstring = ""
                    rqchapterarray.each { |e|
                      rqchapterstring += e.to_i.to_s.rjust(@@chapterdigits, "0")+"."
                    }
                    rqchapter = IssueDocPrefix + rqchapterstring
                    #print(rqchapter)
                    rqstatus = status_dict[r[issue_upload_status_column+1]]
                    rqtarget = r[issue_upload_target_column+1]

                    # Usando el identificador del documento, determinamos si este ya existe o hay que crearlo
                    thisIssue = @project.issues.find_by_subject(issuesubjstr)
                    if (thisIssue == nil) then
                      # no existe el Issue asociado a la fila, lo creo
                      print ("Creando Isssue " + issuesubjstr)
                      thisIssue = @project.issues.new
                      thisIssue.author = User.current
                      thisIssue.tracker = "Req"
                      thisIssue.subject = issuesubjstr
                      if (descr != nil) then
                        #print("description: ",descr)
                        thisIssue.description = descr
                      end
                      thisIssue.save
                    else                      
                      #print("si existe el Isssue")
                      thisIssue.tracker = "Req"
                      if (descr != nil) then
                        #print("description: ",descr)
                        thisIssue.description = descr
                      end
                    end
                    if (rqstatus != nil) then
                      #print("rqstatus: ",rqstatus)
                      thisIssue.status = IssueStatus.find(rqstatus)
                    end
                    if (rqtarget != nil) then
                      #print("rqtarget: ",rqtarget)
                      findVersionSuccess = false
                      thisVersion = nil
                      #print("num versiones: ",@project.versions.size)
                      @project.versions.each { |v|  
                        if not(findVersionSuccess) then
                          if (v.name == rqtarget) then
                            #print("LO ENCONTRE!!")
                            findVersionSuccess = true
                            thisVersion = v
                          else
                            #print("NO.....")
                          end                                
                        end
                      }
                      if (findVersionSuccess) then
                        #print("this version succes????:",findVersionSuccess)
                        #print("thisVersionId: ",thisVersion.id)
                        thisIssue.fixed_version = thisVersion
                      end
                    end                        
                    if (rqchapter != nil) then
                      #print("rqchapter: ",rqchapter)
                      cfc = thisIssue.custom_values.find_by_custom_field_id(@@cfchapter.id)
                      cfc.value = rqchapter
                      cfc.save
                    end
                    thisIssue.save
                    #print("He actualizado o creado el Isssue con id "+thisIssue.id.to_s)

                    current_row += 1
                  end        
                end
                sheetindex += 1
                thissheet = book.worksheets(sheetindex)
              end




# Ahora buscamos las relaciones entre Issues padres e hijos, y de dependencia.
              sheetindex = 1
              thissheet = book.worksheets(sheetindex)
              while (thissheet != nil) do
                docidstr = thissheet.name
                if ((docidstr[0] != '_') and (thissheet != dictsheet) and (thissheet != introsheet) and (thissheet != templatesheet)) then
                  # Tratamos la hoja en concreto
                  #print("DocID: "+docidstr)
                  # Usando el identificador del documento, determinamos si este ya existe o hay que crearlo
                  current_row = issue_upload_first_row+1
                  while (current_row <= issue_upload_end_row) do
                    r = thissheet.row(current_row)
                    #print("\nTrato la fila "+ current_row.to_s)
                    # Estamos procesando las lineas de Issues
                    issuesubjstr = r[issue_upload_subject_column+1]
                    #print("rqid: "+issuesubjstr)
                    thisIssue = @project.issues.find_by_subject(issuesubjstr)
                    if (thisIssue != nil) then

                      parent_str = r[issue_upload_parent_column+1]
                      related_str = r[issue_upload_related_column+1]


                      if (parent_str != nil) then
                        #print("parent_str: ",parent_str)
                        parentissue = @project.issues.find_by_subject(parent_str)
                        if (parentissue != nil) then 
                          #print("parent: ",parentissue)
                          #print("parent id:",parentissue.id)
                          thisIssue.parent = parentissue
                        else
                          print("ERROR: No encontramos el Isssue padre!!!")
                        end
                      else
                        # El Isssue no tiene padre, asi que su padre sera el documento
                        thisIssue.parent = thisdoc
                      end

                      # Exploramos ahora las relaciones de dependencia
                      # Busco las relaciones existences con este Isssue
                      # Como voy a tratar las que tienen el Isssue como destino, las filtro
                      my_filtered_issue_relations = thisIssue.relations_to
                      # Al cargar Issues puede ser que haya antiguas relaciones que ya no existan.  Al finalizar la carga
                      # deberemos eliminar los remanentes, asi que meteremos la lista de relaciones en una lista de remanentes
                      residual_relations = [] 
                      my_filtered_issue_relations.each { |e|
                        if (e.relation_type == 'blocks') then
                          residual_relations << e
                        end
                      }
                      #print("residual_relations BEFORE",residual_relations)

                      if (related_str != nil) then
                        #print("\nrelated: '"+related_str+"'")
                        if (related_str[0]!='-') then
                          # Ahora saco todos los ID de los Issues del otro lado (en el lado origen de la relacion)
                          related_issue = related_str.split()
                          related_iss.each { |rIssue|
                            rIssue = rIssue.strip()
                            #print("\n  related to: '"+rIssue+"'")
                            # Busco ese Isssue
                            blocking_issue = @project.issues.find_by_subject(rIssue)
                            if (blocking_issue != nil) then
                              #print(" encontrado ",blocking_iss.id)
                              # Veo si ya existe algun tipo de relacion con el
                              preexistent_relations = thisIssue.relations_to.where(issue_from: blocking_iss)
                              #print(preexistent_relations)
                              already_exists = false
                              if (preexistent_relations.size>0) then
                                preexistent_relations.each { |rel|
                                  if (rel.relation_type == 'blocks') then
                                    #print("Ya existe la relacion ",rel)
                                    residual_relations.delete(rel)
                                    already_exists = true
                                  end
                                }
                              end
                              if not(already_exists) then
                                #print("Creo una nueva relacion")
                                relation = blocking_iss.relations_from.new
                                relation.issue_to=thisIssue
                                relation.relation_type='blocks'
                                relation.save
                              end

                            else
                              print("Error, no existe el Isssue bloqueante")
                            end
                          }
                        end
                      end

                      # Hay que eliminar todas las relaciones preexistentes que no hayan sido "reescritas"
                      #print("residual_relations AFTER",residual_relations)
                      residual_relations.each { |r|  
                          #print("Destruyo la relacion", r)
                          r.issue_from.relations_from.delete(r)
                          r.destroy
                      }
                      thisIssue.save
                      #print("He actualizado o creado el Isssue con id "+thisIssue.id.to_s)
                      else
                        print("Error, el Isssue no pudo ser encontrado")
                      end
                    current_row += 1
                  end        
                end
                sheetindex += 1
                thissheet = book.worksheets(sheetindex)
              end
              @output += "UPLOAD successful\n"   
            else
              @output += "Error: the upload file is not found\n"
              print(uploadfilepath)
            end
          end
        else
          @output += "Error: the repo does not exists\n"  
          print(repodir)            
        end
      end
      if @output.size <= 255 then 
          @output += "Ok: issues uploaded.\n"
          flash[:notice] = @output.to_s
      else
          flash[:notice] = "Message too long\n"
      end
      print(@output)
    end
  end

  def report
    print("\n\n\n\n\n\n")
    if request.get? then
      print("GET!!!!!")
    else
      print("POST!!!!!")
      splitted_url = request.fullpath.split('/cosmosys_issues')
      root_url = request.base_url+splitted_url[0]      
      @output = ""
      # First we check if the setting for the local repo is set
      if (Setting.plugin_cosmosys_issues['repo_local_path'].blank?) then
        # If it is not set, we can not continue
        @output += "Error: the local repos path template is not defined\n"
      else
        # The setting exists, so we can create the origin and destination paths
        repodir = "#{Setting.plugin_cosmosys_issues['repo_local_path']}"
        repodir["%project_id%"] = @project.identifier
        # Now we have to know if the destination directory already exists
        if (File.directory?(repodir)) then
          if (Setting.plugin_cosmosys_issues['relative_reporting_path'].blank?) then
            # If it is not set, we can not continue
            @output += "Error: the relative path to upload file is not set\n"
          else
            reportingpath = repodir + "/" + Setting.plugin_cosmosys_issues['relative_reporting_path']
            if (File.directory?(reportingpath)) then
              imgpath = repodir + "/" + Setting.plugin_cosmosys_issues['relative_img_path']
              if (File.directory?(imgpath)) then
                if not (File.directory?(@@tmpdir)) then
                  require 'fileutils'
                  FileUtils.mkdir_p @@tmpdir
                end
                tmpfile = Tempfile.new('rqdownload',@@tmpdir)
                begin
                  treedata = CosmosysIssuesBase.show_as_json(@project,nil,root_url)
                  tmpfile.write(treedata.to_json) 
                  tmpfile.close
                  comando = "python3 plugins/cosmosys_issues/assets/pythons/IssReports.py #{@project.id} #{reportingpath} #{imgpath} #{root_url} #{tmpfile.path}"
                  require 'open3'
                  print(comando)
                  stdin, stdout, stderr = Open3.popen3("#{comando}")
                  stdin.close
                  stdout.each do |ele|
                    print ("->"+ele+"\n")
                    @output += ele
                  end
                  print("acabo el comando")
                ensure
                   #tmpfile.unlink   # deletes the temp file
                end
                git_commit_repo(@project,"[Issuebot] reports generated")
                git_pull_rm_repo(@project)
                @output += "Ok: reports generated and diagrams updated.\n"
              else
                @output += "Error: the img path is not found\n"
                print(imgpath)
              end
            else
              @output += "Error: the reporting path is not found\n"
              print(reportingpath)
            end
          end
        else
          @output += "Error: the repo does not exists\n"  
          print(repodir)            
        end
      end
      if @output.size <= 255 then 
        flash[:notice] = @output.to_s
      else
        flash[:notice] = "Message too long\n"
      end
      print(@output)
    end
  end

  def download
    print("\n\n\n\n\n\n")
    if request.get? then
      print("GET!!!!!")
    else
      print("POST!!!!!")
      git_pull_repo(@project)
      @output = ""
      # First we check if the setting for the local repo is set
      if (Setting.plugin_cosmosys_issues['repo_local_path'].blank?) then
        # If it is not set, we can not continue
        @output += "Error: the local repos path template is not defined\n"
      else
        # The setting exists, so we can create the origin and destination paths
        repodir = "#{Setting.plugin_cosmosys_issues['repo_local_path']}"
        repodir["%project_id%"]= @project.identifier
        # Now we have to know if the destination directory already exists
        if (File.directory?(repodir)) then
          if (Setting.plugin_cosmosys_issues['relative_downloadfile_path'].blank?) then
            # If it is not set, we can not continue
            @output += "Error: the relative path to the downnload file is not set\n"
          else
            splitted_url = request.fullpath.split('/cosmosys_issues')
            root_url = request.base_url+splitted_url[0]            
            downloadfilepath = repodir + "/" + Setting.plugin_cosmosys_issues['relative_downloadfile_path']
            if (File.directory?(File.dirname(downloadfilepath))) then
              if not (File.directory?(@@tmpdir)) then
                require 'fileutils'
                FileUtils.mkdir_p @@tmpdir
              end            
              tmpfile = Tempfile.new('rqdownload',@@tmpdir)
              begin
                treedata = CosmosysIssuesBase.show_as_json(@project,nil,root_url)
                tmpfile.write(treedata.to_json) 
                tmpfile.close
                comando = "python3 plugins/cosmosys_issues/assets/pythons/IssDownload.py #{@project.id} #{downloadfilepath} #{root_url} #{tmpfile.path}"
                require 'open3'
                print(comando)
                stdin, stdout, stderr = Open3.popen3("#{comando} &")
                stdin.close
                stdout.each do |ele|
                  print ("->"+ele+"\n")
                  @output += ele
                end
                print("acabo el comando")
              ensure
                 #tmpfile.unlink   # deletes the temp file
              end

              #`#{comando}`
              #p output
              git_commit_repo(@project,"[Issuebot] downloadfile generated")
              git_pull_rm_repo(@project)
            else
              @output += "Error: the downloadfile directory is not found\n"
              print("DOWNLOADFILEPATH: " + File.dirname(downloadfilepath))
            end
          end
        else
          @output += "Error: the repo does not exists\n"  
          print(repodir)            
        end
      end
      if @output.size <= 255 then 
          flash[:notice] = @output.to_s
      else
          flash[:notice] = "Message too long\n"
      end
      print(@output)
    end
  end

  def dstopimport
  end

  def dstopexport
  end

  def validate
  end

  def propagate
  end

  def tree
    require 'json'

    if request.get? then
      print("GET!!!!!")
      if (params[:node_id]) then
        print("NODO!!!\n")
        thisnodeid = params[:node_id]
      else
        print("PROYECTO!!!\n")     
        res = @project.issues.where(:parent => nil).limit(1)
        thisnodeid = res.first.id
      end
      thisnode=Issue.find(thisnodeid)

      splitted_url = request.fullpath.split('/cosmosys_issues')
      print("\nsplitted_url: ",splitted_url)
      root_url = splitted_url[0]
      print("\nroot_url: ",root_url)
      print("\nbase_url: ",request.base_url)
      print("\nurl: ",request.url)
      print("\noriginal: ",request.original_url)
      print("\nhost: ",request.host)
      print("\nhost wp: ",request.host_with_port)
      print("\nfiltered_path: ",request.filtered_path)
      print("\nfullpath: ",request.fullpath)
      print("\npath_translated: ",request.path_translated)
      print("\noriginal_fullpath ",request.original_fullpath)
      print("\nserver_name ",request.server_name)
      print("\noriginal_fullpath ",request.original_fullpath)
      print("\npath ",request.path)
      print("\nserver_addr ",request.server_addr)
      print("\nhost ",request.host)
      print("\nremote_host ",request.remote_host)

      treedata = []

      tree_node = create_tree(thisnode,root_url)

      treedata << tree_node

      #print treedata


      respond_to do |format|
        format.html {
          if @output then 
            if @output.size <= 500 then
              flash[:notice] = "Issuetree:\n" + @output.to_s
            else
              flash[:notice] = "Issuetree too long response\n"
            end
          end
        }
        format.json { 
          require 'json'
          ActiveSupport.escape_html_entities_in_json = false
          render json: treedata
          ActiveSupport.escape_html_entities_in_json = true        
        }
      end
    else

      print("POST!!!!!")
      structure = params[:structure]
      json_params_wrapper = JSON.parse(request.body.read())
      structure = json_params_wrapper['structure']
      #print ("structure: \n\n")
      #print structure
      rootnode = structure[0]
      structure.each { |n|
        CosmosysIssuesBase.update_node(n,nil,"",1)
      }
      redirect_to :action => 'tree', :method => :get, :id => @project.id 
    end

  end


  # -------------------------- Filters and actions --------------------

  def git_commit_repo(pr,a_message)
    @output = ""
    # First we check if the setting for the local repo is set
    if (Setting.plugin_cosmosys_issues['repo_local_path'].blank?) then
      # If it is not set, we can not continue
      @output += "Error: the local repos path template is not defined\n"
    else
      # The repo local path is defined
      destdir = "#{Setting.plugin_cosmosys_issues['repo_local_path']}"
      destdir["%project_id%"]= pr.identifier
      comando = "cd #{destdir}; git add ."
      print("\n\n #{comando}")
      `#{comando}`
      comando = "cd #{destdir}; git commit -m \"#{a_message}\""
      print("\n\n #{comando}")
      `#{comando}`

      # Now we have to push to a server repo
      # We must check if we have tu sync with a remote server
      if (Setting.plugin_cosmosys_issues['repo_server_sync']) then
        # The setting says we must sync with a remote server
        if (Setting.plugin_cosmosys_issues['repo_server_path'].blank?) then
          # The setting is not set, so we can not sync with the remote server
          @output += "Error: the remote server URL template is not defined\n"
        else
          remote_url = "#{Setting.plugin_cosmosys_issues['repo_server_path']}"
          remote_url["%project_id%"] = pr.identifier
          comando = "cd #{destdir}; git remote add origin #{remote_url}"
          print("\n\n #{comando}")
          `#{comando}`
          comando = "cd #{destdir}; git pull origin master"
          print("\n\n #{comando}")
          `#{comando}`
          comando = "cd #{destdir}; git push -u origin --all; git push -u origin --tags"
          print("\n\n #{comando}")
          `#{comando}`
        end
      else
        # If the sync is not active, we can conclude that we must create the local repo
        @output += "Info: remote sync not enabled\n"
      end

    end
  end

  def git_pull_rm_repo(pr)
    # NOTE: ANOTHER ALTERNATIVE IS TO PUSH FROM THE NORMAL REPO
    # EXAMPLE: git push --mirror ../../redmine_repos/issue_demo.git/
    if (Setting.plugin_cosmosys_issues['repo_redmine_sync']) then
      # The setting says we must sync with a remote server
      if not(Setting.plugin_cosmosys_issues['repo_redmine_path'].blank?) then
        redminerepodir = "#{Setting.plugin_cosmosys_issues['repo_redmine_path']}"
        redminerepodir["%project_id%"] = pr.identifier
        comando = "cd #{redminerepodir}; git fetch --all"
        print("\n\n #{comando}")
        `#{comando}`
      end
    end                
  end

  def git_pull_repo(pr)
    @output = ""
    # First we check if the setting for the local repo is set
    if (Setting.plugin_cosmosys_issues['repo_local_path'].blank?) then
      # If it is not set, we can not continue
      @output += "Error: the local repos path template is not defined\n"
    else
      # The repo local path is defined
      destdir = "#{Setting.plugin_cosmosys_issues['repo_local_path']}"
      destdir["%project_id%"]= pr.identifier

      # Now we have to push to a server repo
      # We must check if we have tu sync with a remote server
      if (Setting.plugin_cosmosys_issues['repo_server_sync']) then
        # The setting says we must sync with a remote server
        if (Setting.plugin_cosmosys_issues['repo_server_path'].blank?) then
          # The setting is not set, so we can not sync with the remote server
          @output += "Error: the remote server URL template is not defined\n"
        else
          remote_url = "#{Setting.plugin_cosmosys_issues['repo_server_path']}"
          remote_url["%project_id%"] = pr.identifier
          comando = "cd #{destdir}; git pull origin master"
          print("\n\n #{comando}")
          `#{comando}`
          git_pull_rm_repo(pr)
        end
      else
        # If the sync is not active, we can conclude that we must create the local repo
        @output += "Info: remote sync not enabled\n"
      end
    end
  end


  def create_tree(current_issue, root_url)
    output = ""
    output += ("\nissue: " + current_issue.subject)
    issue_url = root_url + '/issues/' + current_issue.id.to_s
    output += ("\nissue_url: " + issue_url.to_s)
    issue_new_url = root_url + '/projects/' + current_issue.project.identifier + '/issues/new?issue[parent_issue_id]=' + current_issue.id.to_s + '&issue[tracker_id]=' + "Req"
    output += ("\nissue_new_url: " + issue_new_url.to_s)
      issue_new_doc_url = root_url + '/projects/' + current_issue.project.identifier + '/issues/new?issue[parent_issue_id]=' + current_issue.id.to_s + '&issue[tracker_id]=' +  + "Req"
    output += ("\nissue_new_url: " + issue_new_doc_url.to_s)

    cftitlevalue = current_issue.subject
    cfchaptervalue = current_issue.custom_values.find_by_custom_field_id(@@cfchapter.id).value
    separator_idx = cfchaptervalue.rindex('-')
    cfchapterarraywrapper = [cfchaptervalue.slice(0..separator_idx), cfchaptervalue.slice((separator_idx+1)..-1)]
    #print(cfchapterarraywrapper)
    cfchapterstring = cfchapterarraywrapper[0]
    if (cfchapterarraywrapper[1] != nil) then 
      cfchapterarray = cfchapterarraywrapper[1].split('.')
      cfchapterarray.each { |e|
        cfchapterstring += e.to_i.to_s + "."
      }
    end
    tree_node = {'title':  cfchapterstring + " " + current_issue.subject,
             'subtitle': current_issue.description,
             'expanded': true,
             'id': current_issue.id.to_s,
             'return_url': root_url+'/cosmosys_issues/'+current_issue.project.id.to_s+'/tree.json',
             'issue_show_url': issue_url,
             'issue_new_url': issue_new_url,
             'issue_new_doc_url': issue_new_doc_url,
             'issue_edit_url': issue_url+"/edit",
             'children': []
            }

    #print tree_node
    #print "children: " + tree_node[:children].to_s + "++++\n"

    childrenitems = current_issue.children.sort_by {|obj| obj.custom_values.find_by_custom_field_id(@@cfchapter.id).value}
    childrenitems.each{|c|
        child_node = create_tree(c,root_url)
        tree_node[:children] << child_node
    }

    return tree_node
  end



  def find_project
    # @project variable must be set before calling the authorize filter
    if (params[:node_id]) then
      @issue = Issue.find(params[:node_id])
      @project = @issue.project
    else
      if(params[:id]) then
        @project = Project.find(params[:id])
      else
        @project = Project.first
      end
    end
    #print("Project: "+@project.to_s+"\n")
  end

end
