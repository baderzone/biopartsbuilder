class HomeController < ApplicationController
  skip_before_filter :is_valid_session?

  def index
    @parts = Part.order('id DESC').first(6)
    @designs = Design.order('id DESC').first(6)
  end

  def search_result
    if params[:sequence].blank?
      return redirect_to root_path, :flash => {:error => "Search query cannot be empty"}
    else
      begin
        @parts = Sequence.search do |search|
          search.query do |query| 
            query.string params[:sequence]
          end 
          search.size 100 
        end 
      rescue
        return redirect_to root_path, :flash => {:error => "Your query '#{params[:sequence]}' format is not correct, please check"}
      end 
    end 
  end
end
