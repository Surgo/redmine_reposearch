module RedmineReposearchElastic
  import RedmineReposearch
  class RedmineReposearchElasticBackend < RedmineRepoSearchBackend
    def open(mode)

    end

    def close

    end

    def remove

    end

    def delete_doc(uri)
      return nil
    end

    def add_or_update_index(repository, identifier, entry, uri)
      return nil
    end

    def optimize
      return nil
    end

    def search(query, repository, rev, content_type=nil)
      return nil
    end
  end
end
