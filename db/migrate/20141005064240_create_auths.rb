class CreateAuths < ActiveRecord::Migration
  def up
    create_table :auths do |t|
      t.string :username
      t.string :password
      t.integer :foursquare_id
      t.string :foursquare_token
      t.string :weibo_token
      t.timestamps
    end
  end

  def down
    drop_table :auths
  end
end
