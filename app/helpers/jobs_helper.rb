module JobsHelper

  def get_status_label_style(status_tag)
    if status_tag == :finished
      return 'label-success'
    elsif status_tag == :failed
      return 'label-important'
    else
      return 'label-info'
    end
  end

end
