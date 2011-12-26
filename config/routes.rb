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

ActionController::Routing::Routes.draw do |map|
  map.with_options :controller => 'reposearch' do |reposearch|
    reposearch.connect 'projects/:id/reposearch', :action => 'search'
    reposearch.connect 'reposearch', :action => 'search'
  end
  map.with_options :controller => 'repoindexer' do |repoindexer|
    repoindexer.connect 'repoindexer/init/:id', :action => 'indexing', :conditions => {:method => :get}, :init => true
    repoindexer.connect 'repoindexer/crawl/:id', :action => 'indexing', :conditions => {:method => :get}, :init => false
  end
end
