class CreateSites < ActiveRecord::Migration
  def change
    create_table :sites do |t|
      t.belongs_to :user

      t.string :name
      t.string :urls

      t.timestamps
    end
  end
end
