class Ability
  include CanCan::Ability

  def initialize(user)
    
    user ||= User.new
    
    if user.group.name == 'admin'
      can :manage, :all
    elsif user.group.name == 'user'
      can :manage, :all
      cannot :manage, :admin
    else
      can :read, :home
    end
  end
end
