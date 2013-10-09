class FileConvert < ActiveRecord::Base
  belongs_to :user

  attr_accessible :name, :user_id

  def to_s
    name
  end
end
