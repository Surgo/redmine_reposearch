require 'redmine'

Redmine::Plugin.register :redmine_reposearch do
  name 'Redmine Reposearch plugin'
  author 'Kosei Kitahara'
  description 'Full-text search of a repository plugin.'
  version '0.0.1'
  url 'http://surgo.github.com/redmine_reposearch/'
  author_url 'http://surgo.jp/'

  project_module :reposearch do
    permission :reposearch_search, {:reposearch => [:search, ], }
    permission :reposearch_indexing, {:repoindexer => [:indexing, ], }, :public => true
    menu :project_menu, :reposearch, {:controller => 'reposearch', :action => 'search', },
         :caption => :label_reposearch, :param => :id
  end
end
