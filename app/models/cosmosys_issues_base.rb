class CosmosysIssuesBase < ActiveRecord::Base

  @@chapterdigits = 3
  @@cfchapter = IssueCustomField.find_by_name('IssChapter')
  @@cftitle = IssueCustomField.find_by_name('IssTitle')
  @@cfewd = IssueCustomField.find_by_name('IssEstWD')
  @@cfsupervisor = IssueCustomField.find_by_name('Supervisor')
  @@cfvstartdate = VersionCustomField.find_by_name('Start date')
  @@cfvwd = VersionCustomField.find_by_name('Working days')


  def self.cfchapter
    @@cfchapter
  end
  def self.cftitle
    @@cftitle
  end

  def self.get_descendents(n)
    result = []
    n.children.each{|c|
      result.append(c)
      result += self.get_descendents(c)
    }
    return result
  end

  def self.create_json(current_issue, root_url, include_doc_children)
    tree_node = current_issue.attributes.slice("id","tracker_id","subject","description","status_id","fixed_version_id","parent_id","root_id","assigned_to_id","due_date","start_date","done_ratio")
    tree_node[:chapter] = current_issue.custom_values.find_by_custom_field_id(@@cfchapter.id).value
    tree_node[:title] = current_issue.custom_values.find_by_custom_field_id(@@cftitle.id).value
    tree_node[:ewd] = nil
    if @@cfewd != nil then
      cfewd = current_issue.custom_values.find_by_custom_field_id(@@cfewd.id)
      if cfewd != nil then
        tree_node[:ewd] = cfewd.value
      end
    end
    tree_node[:supervisor] = ""
    if @@cfsupervisor != nil then
      cvsupervisor = current_issue.custom_values.find_by_custom_field_id(@@cfsupervisor.id)
      if cvsupervisor != nil then
        tree_node[:supervisor_id] = cvsupervisor.value
        if (cvsupervisor.value != nil) then
          supervisor_id = cvsupervisor.value.to_i
          if (supervisor_id > 0) then  
            tree_node[:supervisor] = User.find(supervisor_id).login
          end
        end
      end
    end
    tree_node[:assigned_to] = []
    if (current_issue.assigned_to != nil) then
      if current_issue.assigned_to.class == Group then
        tree_node[:assigned_to] = [current_issue.assigned_to.lastname]
        current_issue.assigned_to.users.each{|u|
          tree_node[:assigned_to].append(u.login)
        }
      else
        tree_node[:assigned_to] = [current_issue.assigned_to.login]
      end
    end
    if current_issue.children.size == 0 then
      tree_node[:type] = 'Issue'
    else
      tree_node[:type] = 'Info'
    end

    tree_node[:children] = []

    childrenitems = current_issue.children.sort_by {|obj| obj.custom_values.find_by_custom_field_id(@@cfchapter.id).value}
    childrenitems.each{|c|
      if (include_doc_children) then
        child_node = create_json(c,root_url,include_doc_children)
        tree_node[:children] << child_node
      end
    }
    tree_node[:relations] = []
    current_issue.relations_from.where(:relation_type => 'blocks').each{|rl|
      tree_node[:relations] << rl.attributes.slice("issue_to_id")
    }
    tree_node[:relations_back] = []
    current_issue.relations_to.where(:relation_type => 'blocks').each{|rl|
      tree_node[:relations_back] << rl.attributes.slice("issue_from_id")
    }

    return tree_node
  end



  def self.show_as_json(thisproject, node_id,root_url)
    require 'json'

    if (node_id != nil) then
      thisnode = thisproject.issues.find(node_id)
      roots = [thisnode]
    else    
      roots = thisproject.issues.where(:parent => nil)
    end

    treedata = {}

    treedata[:project] = thisproject.attributes.slice("id","name","identifier")
    treedata[:project][:url] = root_url
    treedata[:targets] = {}
    treedata[:statuses] = {}
    treedata[:trackers] = {}
    treedata[:members] = {}
    treedata[:issues] = []

    IssueStatus.all.each { |st| 
      treedata[:statuses][st.id.to_s] = st.name
    }

    Tracker.all.each { |tr| 
      treedata[:trackers][tr.id.to_s] = tr.name
    }

    thisproject.memberships.all.each { |mb| 
      if mb.principal.class == Group then
        treedata[:members][mb.principal.lastname.to_s] = {}
        treedata[:members][mb.principal.lastname.to_s][:firstname] = mb.principal.lastname
        treedata[:members][mb.principal.lastname.to_s][:lastname] = "group" 
        treedata[:members][mb.principal.lastname.to_s][:class] = mb.principal.class.name
      else
        treedata[:members][mb.user.login.to_s] = mb.user.attributes.slice("firstname","lastname")
        treedata[:members][mb.user.login.to_s][:class] = mb.user.class.name
      end
    }

    thisproject.versions.each { |v| 
      treedata[:targets][v.id.to_s] = {}
      treedata[:targets][v.id.to_s][:name] = v.name
      treedata[:targets][v.id.to_s][:due_date] = v.due_date
      treedata[:targets][v.id.to_s][:start_date] = v.custom_values.find_by_custom_field_id(@@cfvstartdate.id).value
      treedata[:targets][v.id.to_s][:working_days] = v.custom_values.find_by_custom_field_id(@@cfvwd.id).value
    }

    roots.each { |r|
      thisnode=r
      tree_node = create_json(thisnode,root_url,true)
      treedata[:issues] << tree_node
    }
    return treedata
  end

  def self.update_node(n,p,prefix,ord)
    # n is node, p is parent
    node = Issue.find(n['id'])
    if (node != nil) then
      nodechapter = prefix+ord.to_s.rjust(@@chapterdigits, "0")+"."
      cfc = node.custom_values.find_by_custom_field_id(@@cfchapter.id)
      cfc.value = nodechapter
      cfc.save      
      if (p != nil) then
        parent = Issue.find(p)
        node.parent = parent
        node.save
      end
      ch = n['children']
      chord = 1
      if (ch != nil) then
         ch.each { |c| 
          update_node(c,node.id,nodechapter,chord)
          chord += 1
        }
      end
    end
  end

  # -----------------------------------

  def self.to_graphviz_depupn(cl,n_node,n,upn,isfirst,torecalc,root_url)
    colorstr = 'black'
    upn_node = cl.add_nodes( upn.id.to_s, :label => "{ "+upn.subject+"|"+upn.custom_values.find_by_custom_field_id(@@cftitle.id).value + "}",
      :style => 'filled', :color => 'black', :fillcolor => 'grey', :shape => 'record',
      :URL => root_url + "/issues/" + upn.id.to_s)
    cl.add_edges(upn_node, n_node, :color => :blue)
    upn.relations_to.each {|upn2|
      cl,torecalc=self.to_graphviz_depupn(cl,upn_node,upn,upn2.issue_from,isfirst,torecalc,root_url)
    }
    if (isfirst) then
      torecalc[upn.id.to_s.to_sym] = upn.id
    end      
    return cl,torecalc
  end



  def self.to_graphviz_depdwn(cl,n_node,n,dwn,isfirst,torecalc,root_url)
      colorstr = 'black'
    dwn_node = cl.add_nodes( dwn.id.to_s, :label => "{ "+dwn.subject+"|"+dwn.custom_values.find_by_custom_field_id(@@cftitle.id).value + "}",
      :style => 'filled', :color => colorstr, :fillcolor => 'grey', :shape => 'record',
      :URL => root_url + "/issues/" + dwn.id.to_s)
    cl.add_edges(n_node, dwn_node, :color => :blue)
    dwn.relations_from.each {|dwn2|
      cl,torecalc=self.to_graphviz_depdwn(cl,dwn_node,dwn,dwn2.issue_to,isfirst,torecalc,root_url)
    }
    if (isfirst) then
      torecalc[dwn.id.to_s.to_sym] = dwn.id
    end  
    return cl,torecalc
  end

  def self.to_graphviz_depcluster(cl,n,isfirst,torecalc,root_url)
    if ((n.children.size > 0)) then
        shapestr = "record"
        desc = self.get_descendents(n)
        added_nodes = []
        desc.each { |e| 
          if (e.relations.size>0) then
            labelstr = "{"+e.subject+"|"+e.custom_values.find_by_custom_field_id(@@cftitle.id).value + "}"      
            e_node = cl.add_nodes(e.id.to_s, :label => labelstr,  
              :style => 'filled', :color => 'black', :fillcolor => 'grey', :shape => shapestr,
              :URL => root_url + "/issues/" + e.id.to_s)
            e.relations_from.each {|r|
              if (not(desc.include?(r.issue_to))) then
                if (not(added_nodes.include?(r.issue_to))) then
                  added_nodes.append(r.issue_to)
                  ext_node = cl.add_nodes(r.issue_to.id.to_s,
              :URL => root_url + "/issues/" + r.issue_to.id.to_s)
                end
              end
              cl.add_edges(e_node, r.issue_to_id.to_s, :color => 'blue')
            }
          end          
        }
        return cl,torecalc
    else
      colorstr = 'black'
      n_node = cl.add_nodes( n.id.to_s, :label => "{"+n.subject+"|"+n.custom_values.find_by_custom_field_id(@@cftitle.id).value + "}",  
        :style => 'filled', :color => colorstr, :fillcolor => 'green', :shape => 'record',
        :URL => root_url + "/issues/" + n.id.to_s)
      n.relations_from.each{|dwn|
        cl,torecalc=self.to_graphviz_depdwn(cl,n_node,n,dwn.issue_to,isfirst,torecalc,root_url)
      }
      n.relations_to.each{|upn|
        cl,torecalc=self.to_graphviz_depupn(cl,n_node,n,upn.issue_from,isfirst,torecalc,root_url)
      }
      return cl,torecalc
    end    
  end

  def self.to_graphviz_depgraph(n,isfirst,torecalc,root_url)
    # Create a new graph
    g = GraphViz.new( :G, :type => :digraph,:margin => 0, :ratio => 'compress', :size => "9.5,30" )
    if ((n.children.size > 0)) then
      labelstr = 'Dependences (in subtree)'
      colorstr = 'orange'
      fontnamestr = 'times italic'
    else
      labelstr = 'Dependences'
      colorstr = 'black'
      fontnamestr = 'times'
    end    
    cl = g.add_graph(:clusterD, :fontname => fontnamestr, :label => labelstr, :labeljust => 'l', :labelloc=>'t', :margin=> '5', :color => colorstr)
    # Generate output image
    cl,torecalc = self.to_graphviz_depcluster(cl,n,isfirst,torecalc,root_url)  
    return g,torecalc
  end


  def self.to_graphviz_hieupn(cl,n_node,n,upn,isfirst,torecalc,root_url)
    colorstr = 'black'
    if upn.children.size > 0 then
      shapestr = "note"
      labelstr = upn.subject+"\n----\n"+upn.custom_values.find_by_custom_field_id(@@cftitle.id).value
      fontnamestr = 'times italic'            
    else
      shapestr = "record"
      labelstr = "{"+upn.subject+"|"+upn.custom_values.find_by_custom_field_id(@@cftitle.id).value + "}"      
      fontnamestr = 'times'
    end
    upn_node = cl.add_nodes( upn.id.to_s, :label => labelstr, :fontname => fontnamestr,
      :style => 'filled', :color => colorstr, :fillcolor => 'grey', :shape => shapestr,
      :URL => root_url + "/issues/" + upn.id.to_s)
    cl.add_edges(upn_node, n_node)
    if (upn.parent != nil) then
      cl,torecalc=self.to_graphviz_hieupn(cl,upn_node,upn,upn.parent,isfirst,torecalc,root_url)
    end
    if (isfirst) then
      torecalc[upn.id.to_s.to_sym] = upn.id
    end  
    return cl,torecalc
  end

  def self.to_graphviz_hiedwn(cl,n_node,n,dwn,isfirst,torecalc,root_url)
    colorstr = 'black'
    if dwn.children.size > 0 then
      shapestr = "note"
      labelstr = dwn.subject+"\n----\n"+dwn.custom_values.find_by_custom_field_id(@@cftitle.id).value
      fontnamestr = 'times italic'            
    else
      shapestr = "record"
      labelstr = "{"+dwn.subject+"|"+dwn.custom_values.find_by_custom_field_id(@@cftitle.id).value + "}"      
      fontnamestr = 'times'
    end
    dwn_node = cl.add_nodes( dwn.id.to_s, :label => labelstr, :fontname => fontnamestr, 
      :style => 'filled', :color => colorstr, :fillcolor => 'grey', :shape => shapestr,
      :URL => root_url + "/issues/" + dwn.id.to_s)
    cl.add_edges(n_node, dwn_node)
    dwn.children.each {|dwn2|
      cl,torecalc=self.to_graphviz_hiedwn(cl,dwn_node,dwn,dwn2,isfirst,torecalc,root_url)
    }
    if (isfirst) then
      torecalc[dwn.id.to_s.to_sym] = dwn.id
    end      
    return cl,torecalc
  end


  def self.to_graphviz_hiecluster(cl,n,isfirst,torecalc,root_url)
    colorstr = 'black'
    if n.children.size > 0 then
      shapestr = "note"
      labelstr = n.subject+"\n----\n"+n.custom_values.find_by_custom_field_id(@@cftitle.id).value
      fontnamestr = 'times italic'            
    else
      shapestr = "record"
      labelstr = "{"+n.subject+"|"+n.custom_values.find_by_custom_field_id(@@cftitle.id).value + "}"      
      fontnamestr = 'times'
    end

    n_node = cl.add_nodes( n.id.to_s, :label => labelstr, :fontname => fontnamestr, 
      :style => 'filled', :color => colorstr, :fillcolor => 'green', :shape => shapestr,
      :URL => root_url + "/issues/" + n.id.to_s)
    n.children.each{|dwn|
      cl,torecalc=self.to_graphviz_hiedwn(cl,n_node,n,dwn,isfirst,torecalc,root_url)
    }
    if (n.parent != nil) then
      cl,torecalc=self.to_graphviz_hieupn(cl,n_node,n,n.parent,isfirst,torecalc,root_url)
    end
    return cl,torecalc
  end

  def self.to_graphviz_hiegraph(n,isfirst,torecalc,root_url)
    # Create a new graph
    g = GraphViz.new( :G, :type => :digraph,:margin => 0, :ratio => 'compress', :size => "9.5,30" )
    cl = g.add_graph(:clusterD, :label => 'Hierarchy', :labeljust => 'l', :labelloc=>'t', :margin=> '5')
    cl,torecalc = self.to_graphviz_hiecluster(cl,n,isfirst,torecalc,root_url)
    return g,torecalc
  end

  def self.to_graphviz_graph_str(n,isfirst,torecalc,root_url)
    g,torecalc = self.to_graphviz_depgraph(n,isfirst,torecalc,root_url)
    result="{{graphviz_link()\n" + g.to_s + "\n}}"
    g2,torecalc = self.to_graphviz_hiegraph(n,isfirst,torecalc,root_url)
    result+=" {{graphviz_link()\n" + g2.to_s + "\n}}"
    return result,torecalc
  end

  def self.show_graphs(n,root_url)
    strdiag,torecalc = self.to_graphviz_graph_str(n,true,{},root_url)
    return strdiag
  end

  def self.show_graphs_pr(p,root_url)
    # Create a new hierarchy graph
    hg = GraphViz.new( :G, :type => :digraph,:margin => 0, :ratio => 'compress', :size => "9.5,30" )
    hcl = hg.add_graph(:clusterD, :label => 'Hierarchy', :labeljust => 'l', :labelloc=>'t', :margin=> '5') 

    # Create a new hierarchy graph
    dg = GraphViz.new( :G, :type => :digraph,:margin => 0, :ratio => 'compress', :size => "9.5,30" )
    dcl = dg.add_graph(:clusterD, :label => 'Dependences', :labeljust => 'l', :labelloc=>'t', :margin=> '5') 

    p.issues.each{|n|
      colorstr = 'black'
      if n.children.size > 0 then
        shapestr = "note"
        labelstr = n.subject+"\n----\n"+n.custom_values.find_by_custom_field_id(@@cftitle.id).value
        fontnamestr = 'times italic'            
      else
        shapestr = "record"
        labelstr = "{"+n.subject+"|"+n.custom_values.find_by_custom_field_id(@@cftitle.id).value + "}"      
        fontnamestr = 'times'
      end
      hn_node = hcl.add_nodes( n.id.to_s, :label => labelstr, :fontname => fontnamestr, 
        :style => 'filled', :color => colorstr, :fillcolor => 'grey', :shape => shapestr,
        :URL => root_url + "/issues/" + n.id.to_s)
      n.children.each{|c|
          hcl.add_edges(hn_node, c.id.to_s)
      }
      if (n.relations.size>0) then
        dn_node = dcl.add_nodes( n.id.to_s, :label => labelstr, :fontname => fontnamestr,   
          :style => 'filled', :color => colorstr, :fillcolor => 'grey', :shape => shapestr,
          :URL => root_url + "/issues/" + n.id.to_s)
        n.relations_from.each {|r|
            dcl.add_edges(dn_node, r.issue_to_id.to_s, :color => 'blue')
        }
      end
    }

    result="{{graphviz_link()\n" + hg.to_s + "\n}}"
    result+=" {{graphviz_link()\n" + dg.to_s + "\n}}"

    return result
  end



end
