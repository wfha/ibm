class Category < ActiveRecord::Base
  #All Attributes:
  #========================================================================
  #class CreateCategories < ActiveRecord::Migration
  #  def change
  #    create_table :categories do |t|
  #      t.string :name
  #      t.string :bei
  #      t.integer :rank
  #      t.string :image
  #      t.references :menu, index: true
  #
  #      t.timestamps
  #    end
  #  end
  #end


  belongs_to :menu

  has_many :dishes, -> { order(:rank) }, :dependent => :destroy
end
