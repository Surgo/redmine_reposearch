Redmine reposearch plugin
=========================

Add full-text search engine to repositories.

Authors
-------

* `Kosei Kitahara`_ (`@Surgo`_)

.. _Kosei Kitahara: http://surgo.jp/
.. _@Surgo: http://twitter.com/Surgo

Links
-----

 * [Project page](http://surgo.github.com/redmine_reposearch/)
 * [Issues](https://github.com/Surgo/redmine_reposearch/issues)
 * [Source code](https://github.com/Surgo/redmine_reposearch)
 * [Documents](https://github.com/Surgo/redmine_reposearch/wiki)

Document (English)
==================

Requirements
------------

* `Redmine`_  (>=1.1)
* `Hyper Estraier`_
* `Ruby Binding of Hyper Estraier`_

Special Thanks to `Redmine`_ and `FAL Labs`_.

.. _Redmine: http://www.redmine.org/
.. _Hyper Estraier: http://fallabs.com/hyperestraier/index.html
.. _Ruby Binding of Hyper Estraier: http://fallabs.com/hyperestraier/rubynativeapi/
.. _FAL Labs: http://fallabs.com/

Install
-------

Ex) Ubuntu.

#. Install Hyper Estraier / Ruby Binding::

       sudo apt-get install hyperestraier libestraier-ruby

   In RPM dist, like ``yum install ruby-hyperestraier``.

#. `Install plugin to redmine`_::

       cd /usr/share/redmine/vendor/plugin/
       sudo git clone git://github.com/Surgo/redmine_reposearch.git
       sudo rake db:migrate_plugins RAILS_ENV=production

.. _Install plugin to redmine: http://www.redmine.org/projects/redmine/wiki/Plugins

That's all!

Pages and Commands
------------------

Pages (for users)
^^^^^^^^^^^^^^^^^

* http://<*redmine.site*>/<*project*>/**reposearch** -- Search codes in project's / sub-project's accessiable repositories.
* http://<*redmine.site*>/**reposearch** -- Search codes in all accessiable repositories.

Commands (for SCM commit hook)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
* http://<*redmine.site*>/**repoindexer**/**init**/<*project*> -- Create / Re-create project's indexes.
* http://<*redmine.site*>/**repoindexer**/**crawl**/<*project*> -- Crawl project's indexes (Indexing if updated).

Usage
-----

Start indexing
^^^^^^^^^^^^^^

*Replace* `SCM commit hook`_ to "Crawl project's indexes". In crawl command, its fetch changeset.

* Ex) Subversion::

      # /path/to/svn/repository/hooks/post-commit
      curl "http://<redmine.site>/repoindexer/crawl/<project>"

  Or::

      wget "http://<redmine.site>/repoindexer/crawl/<project>"

.. _SCM commit hook: http://www.redmine.org/projects/redmine/wiki/HowTo_setup_automatic_refresh_of_repositories_in_Redmine_on_commit

Code search
^^^^^^^^^^^

Just enable **RepoSearch** Module to each projects.
