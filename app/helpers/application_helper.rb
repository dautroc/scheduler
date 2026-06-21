module ApplicationHelper
  # Whether the compiled Tailwind stylesheet is present in the asset load path.
  # Used to guard `stylesheet_link_tag "tailwind"` so the layout never 500s when
  # the build artifact is missing (fresh checkout, after `tailwindcss:clobber`,
  # or CI before the first build) — pages simply render unstyled instead.
  #
  # Note: Propshaft's `load_path.find` returns nil (does NOT raise) when an asset
  # is absent; the raise happens later inside `stylesheet_link_tag`, so we must
  # check the nil return value here.
  def tailwind_asset_exists?
    return false if Rails.application.assets.nil?

    !Rails.application.assets.load_path.find("tailwind.css").nil?
  end

  # Tailwind classes for an appointment status badge.
  def status_badge_class(status)
    case status.to_s
    when "confirmed"
      "bg-emerald-50 text-emerald-700 ring-emerald-600/20"
    when "requested"
      "bg-amber-50 text-amber-800 ring-amber-600/20"
    when "cancelled"
      "bg-slate-100 text-slate-600 ring-slate-500/20"
    else
      "bg-slate-100 text-slate-600 ring-slate-500/20"
    end
  end

  # Up to two uppercase initials for an avatar bubble, e.g. "Jordan Lee" -> "JL".
  def initials(name)
    name.to_s.split(/\s+/).first(2).map { |w| w[0] }.join.upcase
  end

  # Deterministic Tailwind background color for an avatar, keyed off the name.
  AVATAR_COLORS = %w[
    bg-rose-500 bg-pink-500 bg-fuchsia-500 bg-violet-500 bg-indigo-500
    bg-blue-500 bg-sky-500 bg-cyan-500 bg-teal-500 bg-emerald-500
    bg-green-500 bg-amber-500 bg-orange-500
  ].freeze

  def avatar_color(name)
    sum = name.to_s.each_char.sum(&:ord)
    AVATAR_COLORS[sum % AVATAR_COLORS.size]
  end

  # Format a datetime for display in the app's local-style layout.
  def fmt_date_time(t)
    return "—" unless t
    t.in_time_zone(Time.zone).strftime("%b %-d, %Y · %H:%M")
  end

  def fmt_time(t)
    return "—" unless t
    t.in_time_zone(Time.zone).strftime("%H:%M")
  end

  # Returns the "active" nav class when the given path matches the current request.
  def nav_link_class(name, path)
    base = "px-3 py-2 rounded-md text-sm font-medium transition-colors"
    active = current_page?(path)
    if active
      "#{base} bg-brand-50 text-brand-700"
    else
      "#{base} text-slate-600 hover:text-slate-900 hover:bg-slate-100"
    end
  end
end
