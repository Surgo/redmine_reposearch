class Indexinglog < ActiveRecord::Base
  unloadable

  belongs_to :repository
  belongs_to :changeset

  validates_presence_of :repository_id
  validates_presence_of :changeset_id

  attr_protected :repository_id
  attr_protected :changeset_id
end
