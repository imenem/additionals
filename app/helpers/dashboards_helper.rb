module DashboardsHelper
  def dashboard_sidebar?(dashboard, params)
    if params['enable_sidebar'].blank?
      if dashboard.blank?
        # defaults without dashboard
        !@project.nil?
      else
        dashboard.enable_sidebar?
      end
    else
      Additionals.true? params['enable_sidebar']
    end
  end

  def welcome_overview_name(dashboard = nil)
    name = [l(:label_home)]
    name << dashboard.name if dashboard&.always_expose? || dashboard.present? && !dashboard.system_default?

    safe_join name, Additionals::LIST_SEPARATOR
  end

  def dashboard_css_classes(dashboard)
    classes = ['dashboard', dashboard.dashboard_type.underscore, "dashboard-#{dashboard.id}"]
    safe_join classes, ' '
  end

  def sidebar_dashboards(dashboard, project = nil, user = nil)
    user ||= User.current
    scope = Dashboard.visible.includes([:author])

    scope = if project.present?
              scope = scope.project_only
              scope.where(project_id: project.id)
                   .or(scope.where(system_default: true)
                            .where(project_id: nil))
                   .or(scope.where(author_id: user.id)
                            .where(project_id: nil))
            else
              scope.where dashboard_type: dashboard.dashboard_type
            end

    scope.sorted.to_a
  end

  def render_dashboard_actionlist(active_dashboard, project = nil)
    dashboards = sidebar_dashboards(active_dashboard, project)
    base_css = 'icon icon-dashboard'
    out = []
    dashboards.each do |dashboard|
      css_class = base_css
      dashboard_name = "#{l :label_dashboard}: #{dashboard.name}"
      out << if dashboard.id == active_dashboard.id
               link_to dashboard_name, '#',
                       onclick: 'return false;',
                       class: "#{base_css} disabled"
             else
               dashboard_link dashboard, project,
                              class: css_class,
                              title: l(:label_change_to_dashboard),
                              name: dashboard_name
             end
    end

    safe_join out
  end

  def render_sidebar_dashboards(dashboard, project = nil)
    dashboards = sidebar_dashboards(dashboard, project)
    out = [dashboard_links(l(:label_my_dashboard_plural),
                           dashboard,
                           dashboards.select(&:private?),
                           project),
           dashboard_links(l(:label_shared_dashboard_plural),
                           dashboard,
                           dashboards.select(&:public?),
                           project)]

    out << dashboard_info(dashboard) if dashboard.always_expose? || !dashboard.system_default

    safe_join out
  end

  def dashboard_info(dashboard)
    tag.div class: 'active-dashboards' do
      out = [tag.h3(l(:label_active_dashboard)),
             tag.ul do
               concat tag.ul "#{l :field_name}: #{h dashboard.name}"
               concat tag.ul safe_join([l(:field_author), link_to_user(dashboard.author)], ': ')
               concat tag.ul "#{l :field_created_on}: #{format_time dashboard.created_at}"
               concat tag.ul "#{l :field_updated_on}: #{format_time dashboard.updated_at}"
             end]

      out << tag.div(textilizable(dashboard, :description), class: 'dashboard-description') if dashboard.description.present?

      safe_join out
    end
  end

  def dashboard_links(title, active_dashboard, dashboards, project)
    return '' unless dashboards.any?

    tag.h3(title, class: 'dashboards') +
      tag.ul do
        dashboards.each do |dashboard|
          selected = dashboard.id == if params[:dashboard_id].present?
                                       params[:dashboard_id].to_i
                                     else
                                       active_dashboard.id
                                     end

          css = 'dashboard'
          css << ' selected' if selected
          link = [dashboard_link(dashboard, project, class: css)]
          if dashboard.system_default?
            link << if dashboard.project_id.nil?
                      font_awesome_icon('fas_cube',
                                        title: l(:field_system_default),
                                        class: 'dashboard-system-default global')
                    else
                      font_awesome_icon('fas_cube',
                                        title: l(:field_project_system_default),
                                        class: 'dashboard-system-default project')
                    end
          end
          concat tag.li safe_join(link)
        end
      end
  end

  def dashboard_link(dashboard, project, options = {})
    if options[:title].blank? && dashboard.public?
      author = if dashboard.author_id == User.current.id
                 l :label_me
               else
                 dashboard.author
               end
      options[:title] = l(:label_dashboard_author, name: author)
    end

    name = options.delete(:name) || dashboard.name
    link_to name, dashboard_link_path(project, dashboard), options
  end

  def sidebar_action_toggle(enabled, dashboard, project = nil)
    return if dashboard.nil?

    if enabled
      link_to l(:label_disable_sidebar),
              dashboard_link_path(project, dashboard, enable_sidebar: 0),
              class: 'icon icon-sidebar'
    else
      link_to l(:label_enable_sidebar),
              dashboard_link_path(project, dashboard, enable_sidebar: 1),
              class: 'icon icon-sidebar'
    end
  end

  def delete_dashboard_link(url, options = {})
    options = { method: :delete,
                data: { confirm: l(:text_are_you_sure) },
                class: 'icon icon-del' }.merge(options)

    link_to l(:button_dashboard_delete), url, options
  end

  # Returns the select tag used to add or remove a block
  def dashboard_block_select_tag(dashboard)
    blocks_in_use = dashboard.layout.values.flatten
    options = tag.option "<< #{l :label_add_dashboard_block} >>", value: ''
    dashboard.content.block_options(blocks_in_use).each do |label, block|
      options << tag.option(label, value: block, disabled: block.blank?)
    end
    select_tag 'block',
               options,
               id: 'block-select',
               class: 'dashboard-block-select',
               onchange: "$('#block-form').submit();"
  end

  # Renders the blocks
  def render_dashboard_blocks(blocks, dashboard, _options = {})
    s = ''.html_safe

    if blocks.present?
      blocks.each do |block|
        s << render_dashboard_block(block, dashboard).to_s
      end
    end
    s
  end

  # Renders a single block
  def render_dashboard_block(block, dashboard, overwritten_settings = {})
    block_definition = dashboard.content.find_block block
    unless block_definition
      Rails.logger.warn "Unknown block \"#{block}\" found in #{dashboard.name} (id=#{dashboard.id})"
      return
    end

    content = render_dashboard_block_content block, block_definition, dashboard, overwritten_settings
    return if content.blank?

    if dashboard.editable?
      icons = []
      if block_definition[:no_settings].blank?
        if !block_definition.key?(:with_settings_if) || block_definition[:with_settings_if].call(@project)
          icons << link_to_function(l(:label_options),
                                    "$('##{block}-settings').toggle();",
                                    class: 'icon-only icon-settings',
                                    title: l(:label_options))
        end
      end
      icons << tag.span('', class: 'icon-only icon-sort-handle sort-handle', title: l(:button_move))
      icons << link_to(l(:button_delete),
                       _remove_block_dashboard_path(@project, dashboard, block: block),
                       remote: true, method: 'post',
                       class: 'icon-only icon-close', title: l(:button_delete))

      content = tag.div(safe_join(icons), class: 'contextual') + content
    end

    tag.div content, class: 'mypage-box', id: "block-#{block}"
  end

  def build_dashboard_partial_locals(block, block_definition, settings, dashboard)
    partial_locals = { dashboard: dashboard,
                       settings: settings,
                       block: block,
                       block_definition: block_definition,
                       user: User.current }

    if block_definition[:query_block]
      partial_locals[:query_block] = block_definition[:query_block]
      partial_locals[:klass] = block_definition[:query_block][:class]
      partial_locals[:async] = { required_settings: %i[query_id],
                                 exposed_params: %i[sort],
                                 partial: 'dashboards/blocks/query_list' }
      partial_locals[:async] = partial_locals[:async].merge(block_definition[:async]) if block_definition[:async]
    elsif block_definition[:async]
      partial_locals[:async] = block_definition[:async]
    end

    partial_locals
  end

  def dashboard_async_required_settings?(settings, async)
    return true if async[:required_settings].blank?
    return false if settings.blank?

    async[:required_settings].each do |required_setting|
      return false if settings.exclude?(required_setting) || settings[required_setting].blank?
    end

    true
  end

  def dashboard_query_list_block_title(query, query_block, project)
    title = []
    title << query.project if project.nil? && query.project
    title << query_block[:label]

    title << if query_block[:with_project]
               link_to(query.name, send(query_block[:link_helper], project, query.as_params))
             else
               link_to(query.name, send(query_block[:link_helper], query.as_params))
             end

    safe_join title, Additionals::LIST_SEPARATOR
  end

  def dashboard_query_list_block_alerts(dashboard, query, block_definition)
    return if dashboard.visibility == Dashboard::VISIBILITY_PRIVATE

    title = if query.visibility == Query::VISIBILITY_PRIVATE
              l(:alert_only_visible_by_yourself)
            elsif block_definition.key?(:admin_only) && block_definition[:admin_only]
              l(:alert_only_visible_by_admins)
            end

    return if title.nil?

    font_awesome_icon('fas_info-circle',
                      title: title,
                      class: 'dashboard-block-alert')
  end

  def render_legacy_left_block(_block, _block_definition, _settings, _dashboard)
    if @project
      call_hook :view_projects_show_left, project: @project
    else
      call_hook :view_welcome_index_left
    end
  end

  def render_legacy_right_block(_block, _block_definition, _settings, _dashboard)
    if @project
      call_hook :view_projects_show_right, project: @project
    else
      call_hook :view_welcome_index_right
    end
  end

  # copied from my_helper
  def render_documents_block(block, _block_definition, settings, dashboard)
    max_entries = settings[:max_entries] || DashboardContent::DEFAULT_MAX_ENTRIES

    scope = Document.visible
    scope = scope.where(project: dashboard.project) if dashboard.project

    documents = scope.order(created_on: :desc)
                     .limit(max_entries)
                     .to_a

    render partial: 'dashboards/blocks/documents', locals: { block: block,
                                                             max_entries: max_entries,
                                                             documents: documents }
  end

  def render_news_block(block, _block_definition, settings, dashboard)
    max_entries = settings[:max_entries] || DashboardContent::DEFAULT_MAX_ENTRIES

    news = if dashboard.content_project.nil?
             News.latest User.current
           else
             dashboard.content_project
                      .news
                      .limit(max_entries)
                      .includes(:author, :project)
                      .reorder(created_on: :desc)
                      .to_a
           end

    render partial: 'dashboards/blocks/news', locals: { block: block,
                                                        max_entries: max_entries,
                                                        news: news }
  end

  def render_timelog_block(block, _block_definition, settings, _dashboard)
    days = settings[:days].to_i
    days = 7 if days < 1 || days > 365

    entries = TimeEntry
              .where("#{TimeEntry.table_name}.user_id = ? AND #{TimeEntry.table_name}.spent_on BETWEEN ? AND ?",
                     User.current.id, User.current.today - (days - 1), User.current.today)
              .joins(:activity, :project)
              .references(issue: %i[tracker status])
              .includes(issue: %i[tracker status])
              .order("#{TimeEntry.table_name}.spent_on DESC,
                      #{Project.table_name}.name ASC,
                      #{Tracker.table_name}.position ASC, #{Issue.table_name}.id ASC")
              .to_a
    entries_by_day = entries.group_by(&:spent_on)

    render partial: 'dashboards/blocks/timelog', locals: { block: block, entries: entries, entries_by_day: entries_by_day, days: days }
  end

  def activity_dashboard_data(settings, dashboard)
    max_entries = (settings[:max_entries] || DashboardContent::DEFAULT_MAX_ENTRIES).to_i
    user = User.current
    options = {}
    options[:author] = user if Additionals.true? settings[:me_only]
    options[:project] = dashboard.content_project if dashboard.content_project.present?

    Redmine::Activity::Fetcher.new(user, options)
                              .events(nil, nil, limit: max_entries)
                              .group_by { |event| user.time_to_date(event.event_datetime) }
  end

  def dashboard_feed_catcher(url, max_entries)
    feed = { items: [], valid: false }
    return feed if url.blank?

    cnt = 0
    max_entries = max_entries.present? ? max_entries.to_i : 10

    begin
      URI.open(url) do |rss_feed|
        rss = RSS::Parser.parse(rss_feed)
        rss.items.each do |item|
          cnt += 1
          feed[:items] << { title: item.title.try(:content)&.presence || item.title,
                            link: item.link.try(:href)&.presence || item.link }
          break if cnt >= max_entries
        end
      end
    rescue StandardError => e
      Rails.logger.info "dashboard_feed_catcher error for #{url}: #{e}"
      return feed
    end

    feed[:valid] = true

    feed
  end

  def dashboard_feed_title(title, block_definition)
    title.presence || block_definition[:label]
  end

  private

  # Renders a single block content
  def render_dashboard_block_content(block, block_definition, dashboard, overwritten_settings = {})
    settings = dashboard.layout_settings block
    settings = settings.merge(overwritten_settings) if overwritten_settings.present?

    partial = block_definition[:partial]
    partial_locals = build_dashboard_partial_locals block, block_definition, settings, dashboard

    if block_definition[:query_block] || block_definition[:async]
      render partial: 'dashboards/blocks/async', locals: partial_locals
    elsif partial
      begin
        render partial: partial, locals: partial_locals
      rescue ActionView::MissingTemplate
        Rails.logger.warn("Partial \"#{partial}\" missing for block \"#{block}\" found in #{dashboard.name} (id=#{dashboard.id})")
        nil
      end
    else
      send "render_#{block_definition[:name]}_block",
           block,
           block_definition,
           settings,
           dashboard
    end
  end

  def resently_used_dashboard_save(dashboard, project = nil)
    user = User.current
    dashboard_type = dashboard.dashboard_type
    recently_id = user.pref.recently_used_dashboard dashboard_type, project
    return if recently_id == dashboard.id || user.anonymous?

    if dashboard_type == DashboardContentProject::TYPE_NAME
      user.pref.recently_used_dashboards[dashboard_type] = {} if user.pref.recently_used_dashboards[dashboard_type].nil?
      user.pref.recently_used_dashboards[dashboard_type][project.id] = dashboard.id
    else
      user.pref.recently_used_dashboards[dashboard_type] = dashboard.id
    end

    user.pref.save
  end
end
