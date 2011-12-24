class CreateIndexinglogs < ActiveRecord::Migration
  def self.up
    create_table :indexinglogs do |t|

      t.column :repository_id, :integer

      t.column :changeset_id, :integer

      t.column :status, :integer

      t.column :message, :string

      t.column :created_at, :timestamp

      t.column :updated_at, :timestamp

    end
  end

  def self.down
    drop_table :indexinglogs
  end
end
