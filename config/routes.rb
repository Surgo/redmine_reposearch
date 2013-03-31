#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
#
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

RedmineApp::Application.routes.draw do
  match 'projects/:id/reposearch', :controller => 'reposearch',
    :action => 'search', :via => :get
  match 'repoindexer/init/:id', :to => 'repoindexer#indexing',
    :action => 'indexing', :init => true, :via => :get
  match 'repoindexer/crawl/:id', :to => 'repoindexer#indexing',
    :action => 'indexing', :init => false, :via => :get
end
