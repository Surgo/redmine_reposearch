# Redmine reposearch plugin
# Copyright (C) Kosei Kitahara.
# 
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

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
