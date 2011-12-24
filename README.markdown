Redmine reposearch plugin
-------------------------

Full-text search of a repository plugin.

Authors
-------

 * Kosei Kitahara (@Surgo)

Requirements
------------

* [Redmine 1.1](http://www.redmine.org/)
* [Hyper Estraier](http://fallabs.com/hyperestraier/index.html)
* [Hyper Estraier Ruby Binding](http://fallabs.com/hyperestraier/rubynativeapi/)

Install
-------

For Ubuntu.

1. Install Hyper Estraier / Hyper Estraier Ruby Binding
   `sudo apt-get install hyperestraier libestraier-ruby`
2. [Install redmine plugin](http://www.redmine.org/projects/redmine/wiki/Plugins)

That's all!

Page / Commands
---------------

* http://your.redmine.site/[project]/reposearch -- Search codes in project's / sub-project's accessiable repositories.
* http://your.redmine.site/reposearch -- Search codes in all accessiable repositories.
* http://your.redmine.site/repoindexer/init/[project] -- Create / Re-create project's indexes.
* http://your.redmine.site/repoindexer/init -- Create / Re-create all indexes (take several minutes).
* http://your.redmine.site/repoindexer/indexing/[project] -- Update project's indexes.
* http://your.redmine.site/repoindexer/indexing/[project] -- Update all indexes.

Please replace repository commit hooks to commands for 'update project's indexes'.

Repository
----------

 * [github - Surgo / redmine\_reposearch](https://github.com/Surgo/redmine_reposearch)

