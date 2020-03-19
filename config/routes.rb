# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html
get 'cosmosys_issues/:id/project_menu', :to => 'cosmosys_issues#project_menu'

get 'cosmosys_issues/:id/create_repo', :to => 'cosmosys_issues#create_repo'
get 'cosmosys_issues/:id/upload', :to => 'cosmosys_issues#upload'
get 'cosmosys_issues/:id/download', :to => 'cosmosys_issues#download'
get 'cosmosys_issues/:id/dstopimport', :to => 'cosmosys_issues#dstopimport'
get 'cosmosys_issues/:id/dstopexport', :to => 'cosmosys_issues#dstopexport'
get 'cosmosys_issues/:id/report', :to => 'cosmosys_issues#report'
get 'cosmosys_issues/:id/validate', :to => 'cosmosys_issues#validate'
get 'cosmosys_issues/:id/propagate', :to => 'cosmosys_issues#propagate'
get 'cosmosys_issues/:id/tree', :to => 'cosmosys_issues#tree'

post 'cosmosys_issues/:id/create_repo', :to => 'cosmosys_issues#create_repo'
post 'cosmosys_issues/:id/upload', :to => 'cosmosys_issues#upload'
post 'cosmosys_issues/:id/download', :to => 'cosmosys_issues#download'
post 'cosmosys_issues/:id/dstopimport', :to => 'cosmosys_issues#dstopimport'
post 'cosmosys_issues/:id/dstopexport', :to => 'cosmosys_issues#dstopexport'
post 'cosmosys_issues/:id/report', :to => 'cosmosys_issues#report'
post 'cosmosys_issues/:id/validate', :to => 'cosmosys_issues#validate'
post 'cosmosys_issues/:id/propagate', :to => 'cosmosys_issues#propagate'
post 'cosmosys_issues/:id/tree', :to => 'cosmosys_issues#tree'

get 'cosmosys_issues/:id/issue_menu', :to => 'cosmosys_issues#issue_menu'

get 'cosmosys_issues/:id/issue_validate', :to => 'cosmosys_issues#issue_validate'
get 'cosmosys_issues/:id/issue_propagate', :to => 'cosmosys_issues#issue_propagate'
get 'cosmosys_issues/:id/issues_tree', :to => 'cosmosys_issues#issues_tree'

post 'cosmosys_issues/:id/issue_validate', :to => 'cosmosys_issues#issue_validate'
post 'cosmosys_issues/:id/issue_propagate', :to => 'cosmosys_issues#issue_propagate'
post 'cosmosys_issues/:id/issues_tree', :to => 'cosmosys_issues#issues_tree'

get 'cosmosys_issues/:id', :to => 'cosmosys_issues#show'
