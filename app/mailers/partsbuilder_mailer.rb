class PartsbuilderMailer < ActionMailer::Base
  default from: "syntheticyeast1@gmail.com"

  def finished_notice(user, error)
    @user = user
    @error = error
    mail(:to => user.email, :subject => "PartsBuilder Finished")
  end 

end
