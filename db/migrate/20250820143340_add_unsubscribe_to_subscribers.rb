class AddUnsubscribeToSubscribers < ActiveRecord::Migration[8.0]
  def change
    add_column :subscribers, :unsubscribed, :boolean
    add_column :subscribers, :unsubscribed_at, :datetime
  end
end
