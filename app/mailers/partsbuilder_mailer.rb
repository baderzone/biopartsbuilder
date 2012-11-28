class PartsbuilderMailer < ActionMailer::Base
  default from: "syntheticyeast1@gmail.com"

  def finished_notice(user)
    @user = user
    mail(:to => user.email, :subject => "PartsBuilder Finished")
  end 

end
