class CreatePages < ActiveRecord::Migration
  def self.up
    create_table :pages do |t|
      t.string :url
      t.string :title
      t.text :content
      t.string :image
      t.string :embed

      t.timestamps
    end
  end

  def self.down
    drop_table :pages
  end
end