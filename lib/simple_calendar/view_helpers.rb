module SimpleCalendar
  module ViewHelpers

    def calendar(events, options={}, &block)
      raise 'SimpleCalendar requires a block to be passed in' unless block_given?

      opts = default_options
      options.reverse_merge! opts
      events       ||= []
      selected_month = Date.new(options[:year], options[:month])
      current_date   = Date.today
      range          = build_range selected_month, options
      month_array    = range.each_slice(7).to_a

      draw_calendar(selected_month, month_array, current_date, events, options, block)
    end

    private
    def default_options
      {
          :year       => (params[:year] || Time.zone.now.year).to_i,
          :month      => (params[:month] || Time.zone.now.month).to_i,
          :prev_text  => raw("&laquo;"),
          :next_text  => raw("&raquo;"),
          :start_day  => :sunday,
          :class      => "table table-bordered table-striped calendar",
          :params     => {}
      }
    end
    # Returns array of dates between start date and end date for selected month
    def build_range(selected_month, options)
      start_date = selected_month.beginning_of_month.beginning_of_week(options[:start_day])
      end_date   = selected_month.end_of_month.end_of_week(options[:start_day])

      (start_date..end_date).to_a
    end

    # Renders the calendar table
    def draw_calendar(selected_month, month, current_date, events, options, block)
      tags = []
      today = Date.today
      content_tag(:table, :class => options[:class]) do
        tags << month_header(selected_month, options)
        
        tags << build_thead_section(selected_month)
        tags << build_month_section(month, today, selected_month, events, options, block)

        tags.join.html_safe
      end #content_tag :table
    end

    def build_td_class(selected_month, day, events)
      today = Date.today
      td_class = ["day"]
      td_class << "today" if today == day
      td_class << "not-current-month" if selected_month.month != day.month
      td_class << "past" if today > day
      td_class << "future" if today < day
      td_class << "wday-#{day.wday.to_s}" # <- to enable different styles for weekend, etc
      td_class << (events.any? ? "events" : "no-events")
    end
    
    def set_current_week_class(week, day)
      "current-week" if week.include?(day)
    end
    
    def set_current_day_class(selected_month, day)
      if (selected_month.month == day.month && day.strftime("%a") == name)
        "current-day"
      end
    end
    
    def build_thead_content(day_names, options={})
      tr_content = day_names.collect { |name| content_tag(:th, name, options)}
      content_tag(:tr, tr_content.join.html_safe)
    end
    
    def build_thead_section(selected_month)
      day_names = I18n.t("date.abbr_day_names")
      day_names = day_names.rotate((Date::DAYS_INTO_WEEK[options[:start_day]] + 1) % 7)
      
      th_tr_class = set_current_day_class(selected_month, Date.today) 
      content_tag(:thead, build_thead_content(day_names, {:class => th_tr_class}))
    end
    
    def build_events_div(events, day, options, block)
      content_tag(:div) do
        divs = []
        concat content_tag(:div, day.day.to_s, :class=>"day_number")

        if events.empty? && options[:empty_date]
          concat options[:empty_date].call(day)
        else
          divs << events.collect{ |event| block.call(event) }
        end

        divs.join.html_safe
      end #content_tag :div
    end
    
    def build_day_section(selected_month, day, events, options, block)
      cur_events = day_events(day, events)

      td_class = build_td_class(selected_month, day, cur_events)
      
      # for rails >= 3.2, we can use :data symbol with hash
      data = {:date-iso => day.to_s, :date => day.to_s.gsub('-', '/')}
      
      content_tag(:td, :class => td_class.join(" "), :data => data) do
        build_events_div(cur_events, day, options, block)
      end #content_tag :td
    end
    
    def build_week_section(week, today, selected_month, events, options, block)
      content_tag(:tr, :class => 'week '+set_current_week_class(week, today)) do
        days = week.collect do |day|
          build_day_section(selected_month, day, events, options, block)
        end
        days.join.html_safe
      end #content_tag :tr
    end
    
    def build_month_section(month, today, selected_month, events, options, block)
      data = {:month => selected_month.month, :year => select_month.year}
      content_tag(:tbody, :data => data) do
        weeks = month.collect do |week|
          build_week_section(week, today, selected_month, events, options, block)
        end
        weeks.join.html_safe
      end
    end
    # Returns an array of events for a given day
    def day_events(date, events)
      events.select { |e| e.start_time.to_date == date }.sort_by { |e| e.start_time }
    end

    # Generates the header that includes the month and next and previous months
    def month_header(selected_month, options)
      content_tag :h2 do
        previous_month = selected_month.advance :months => -1
        next_month = selected_month.advance :months => 1
        tags = []

        tags << month_link(options[:prev_text], previous_month, options[:params], {:class => "previous-month"})
        tags << "#{I18n.t("date.month_names")[selected_month.month]} #{selected_month.year}"
        tags << month_link(options[:next_text], next_month, options[:params], {:class => "next-month"})

        tags.join.html_safe
      end
    end

    # Generates the link to next and previous months
    def month_link(text, date, params, opts={})
      link_to(text, params.merge({:month => date.month, :year => date.year}), opts)
    end
  end
end
