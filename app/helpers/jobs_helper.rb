module JobsHelper

  def get_status_label_style(status_tag)
    if status_tag == 'finished'
      return 'label-success'
    elsif status_tag == 'failed'
      return 'label-important'
    else
      return 'label-info'
    end
  end

  def get_type_style(type_tag)
    if type_tag == 'auto_build'
      return 'text-error'
    elsif type_tag == 'part'
      return 'text-success'
    elsif type_tag == 'design'
      return 'text-info'
    else
      return 'text-warning'
    end
  end

end
