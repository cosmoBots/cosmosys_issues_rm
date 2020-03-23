Redmine::Plugin.register :cosmosys_issues do
  name 'cosmoSys-Issue plugin'
  author 'cosmoBots.eu'
  description 'This plugin converts a Redmine server in a cosmSys-Issue one'
  version '0.0.1'
  url 'http://cosmobots.eu/projects/csysIssue/wiki'
  author_url 'http://cosmobots.eu/'


  permission :view_cosmosys, :cosmosys_issues => :project_menu
  permission :tree_cosmosys, :cosmosys_issues => :tree
  permission :download_cosmosys, :cosmosys_issues => :download
  permission :dstopexport_cosmosys, :cosmosys_issues => :dstopexport
  permission :dstopimport_cosmosys, :cosmosys_issues => :dstopimport
  permission :propagate_cosmosys, :cosmosys_issues => :propagate
  permission :report_cosmosys, :cosmosys_issues => :report
  permission :upload_cosmosys, :cosmosys_issues => :upload
  permission :validate_cosmosys, :cosmosys_issues => :validate
  permission :create_repo, :cosmosys_issues => :create_repo
  permission :show_cosmosys, :cosmosys_issues => :show

  menu :project_menu, :cosmosys_issues, {:controller => 'cosmosys_issues', :action => 'project_menu' }, :caption => 'cosmoSys-Issue', :after => :activity, :param => :id
  menu :project_menu, :cosmosys_issues_tree, {:controller => 'cosmosys_issues', :action => 'tree' }, :caption => 'IssueTree', :after => :issues, :param => :id
  menu :project_menu, :cosmosys_issues_show, {:controller => 'cosmosys_issues', :action => 'show' }, :caption => 'issueshow', :after => :issues, :param => :id

  settings :default => {
    'repo_local_path' => "/home/redmine/repos/issue_%project_id%",
    'repo_server_sync' => :false,
    'repo_server_path'  => 'http://gitlab/issues/issue_%project_id%.git',
    'repo_template_id'  => 'template',
    'repo_redmine_path' => "/home/redmine/repos_redmine/issue_%project_id%.git",
    'repo_redmine_sync' => :true,
    'relative_uploadfile_path' => "uploading/IssUpload.ods",
    'relative_downloadfile_path' => "downloading/IssDownload.ods",
    'relative_reporting_path' => "reporting",
    'relative_img_path' => "reporting/doc/img"
  }, :partial => 'settings/cosmosys_issues_settings'

  require 'cosmosys_issues'

end
