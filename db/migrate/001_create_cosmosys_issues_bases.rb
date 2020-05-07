class CreateCosmosysIssuesBases < ActiveRecord::Migration[5.2]
	def up

		##### CREATE TABLES
		create_table :cosmosys_issues_bases do |t|
			t.string :name
			t.integer :project_id
			t.integer :user_id			
			t.text :result
		end

		tracker_ids = []
		Tracker.all.each{|tr|
			if tr.name = "Req" then
			else
				if tr.name = "ReqDoc" then
				else
					tracker_ids << tr.id
				end
			end
		}
		rqchapterfield = IssueCustomField.create!(:name => 'IssChapter', 
			:field_format => 'string', :searchable => false,
			:is_for_all => true, :tracker_ids => tracker_ids)

		rqtitlefield = IssueCustomField.create!(:name => 'IssTitle', 
			:field_format => 'string', :searchable => true,
			:is_for_all => true, :tracker_ids => tracker_ids)

		rqestwod = IssueCustomField.create!(:name => 'IssEstWD', 
			:field_format => 'float', :description => 'Estimated working days',
			:is_for_all => true, :tracker_ids => tracker_ids)


		link_str = "link"

		# Issue part
		# Create diagrams custom fields
		rqhiediaglink = IssueCustomField.create!(:name => 'IssHierarchyDiagram',
			:field_format => 'link', :description => "A link to the Hierarchy Diagram",
			:url_pattern => "/projects/%project_identifier%/repository/rq/raw/reporting/doc/img/%id%_h.gv.svg",
			:default_value => link_str,
			:is_for_all => true, :tracker_ids => tracker_ids)

		rqdepdiaglink = IssueCustomField.create!(:name => 'IssDependenceDiagram',
			:field_format => 'link', :description => "A link to the Dependence Diagram",
			:url_pattern => "/projects/%project_identifier%/repository/rq/raw/reporting/doc/img/%id%_d.gv.svg",
			:default_value => link_str,
			:is_for_all => true, :tracker_ids => tracker_ids)

		# Project part
		# Create diagrams custom fields
		rqprjhiediaglink = ProjectCustomField.create!(:name => 'IssHierarchyDiagram',
			:field_format => 'link', :description => "A link to the Hierarchy Diagram",
			:url_pattern => "/projects/%project_identifier%/repository/rq/raw/reporting/doc/img/%project_identifier%_h.gv.svg",
			:default_value => link_str)

		rqprjdepdiaglink = ProjectCustomField.create!(:name => 'IssDependenceDiagram',
			:field_format => 'link', :description => "A link to the Dependence Diagram",
			:url_pattern => "/projects/%project_identifier%/repository/rq/raw/reporting/doc/img/%project_identifier%_d.gv.svg",
			:default_value => link_str)

		rqprefixfield = ProjectCustomField.create!(:name => 'IssPrefix', 
			:field_format => 'string', :description => "Prefix for issue IDs",
			:default_value => "TSK", :is_for_all => true, :is_required => true)

		rqidcounter = ProjectCustomField.create!(:name => 'IssCounter', 
			:field_format => 'int', :searchable => false,
			:description => 'Counter for generating identifiers',
			:default_value => '1', :is_required => true, 
			:is_filter => false, :visible => true,
			:is_for_all => true)
    
		link_str = "link"

		Issue.find_each{|i|
      foundhie = false
      founddep = false
      i.custom_values.each{|cf|
        if cf.custom_field_id == rqhiediaglink.id then
          foundhie = true
          cf.value = link_str
          cf.save
        end
        if cf.custom_field_id == rqdepdiaglink.id then
          founddep = true
          cf.value = link_str
          cf.save
        end
      }
      if not foundhie then
        icv = CustomValue.new
        icv.custom_field = rqhiediaglink
        icv.customized = i
        icv.value = link_str
        icv.save
      end
      if not founddep then
        icv = CustomValue.new
        icv.custom_field = rqdepdiaglink
        icv.customized = i
        icv.value = link_str
        icv.save
      end
		}
		Project.find_each{|i|
			foundhie = false
			founddep = false
			i.custom_values.each{|cf|
				if cf.custom_field_id == rqprjhiediaglink.id then
					foundhie = true
					cf.value = link_str
					cf.save
				end
				if cf.custom_field_id == rqprjdepdiaglink.id then
					founddep = true
					cf.value = link_str
					cf.save
				end
			}
			if not foundhie then
				icv = CustomValue.new
				icv.custom_field = rqprjhiediaglink
				icv.customized = i
				icv.value = link_str
				icv.save
			end
			if not founddep then
				icv = CustomValue.new
				icv.custom_field = rqprjdepdiaglink
				icv.customized = i
				icv.value = link_str
				icv.save
			end
		}
	end

	def down
		# Issue part
		tmp = IssueCustomField.find_by_name('IssHierarchyDiagram')
		if (tmp != nil) then
			tmp.destroy
		end
		tmp = IssueCustomField.find_by_name('IssDependenceDiagram')
		if (tmp != nil) then
			tmp.destroy
		end
		# Project part
		tmp = ProjectCustomField.find_by_name('IssHierarchyDiagram')
		if (tmp != nil) then
			tmp.destroy
		end
		tmp = ProjectCustomField.find_by_name('IssDependenceDiagram')
		if (tmp != nil) then
			tmp.destroy
		end
		tmp = ProjectCustomField.find_by_name('IssPrefix')
		if (tmp != nil) then
			tmp.destroy
		end		
		tmp = IssueCustomField.find_by_name('IssEstWD')
		if (tmp != nil) then
			tmp.destroy
		end
		tmp = IssueCustomField.find_by_name('IssChapter')
		if (tmp != nil) then
			tmp.destroy
		end
		tmp = IssueCustomField.find_by_name('IssTitle')
		if (tmp != nil) then
			tmp.destroy
		end
		tmp = ProjectCustomField.find_by_name('IssCounter')
		if (tmp != nil) then
			tmp.destroy
		end    
		drop_table :cosmosys_issue_bases
	end
end
