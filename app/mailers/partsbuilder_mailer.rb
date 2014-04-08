class PartsbuilderMailer < ActionMailer::Base
  default from: "biopartsapps@gmail.com"

  def finished_notice(user, error)
    @user = user
    @error = error
    mail(:to => user.email, :subject => "PartsBuilder Finished")
  end 

end
