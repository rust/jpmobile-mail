# -*- coding: utf-8 -*-
# = viewの自動切り替え
#
#:stopdoc:
# helperを追加
ActionView::Base.class_eval { include Jpmobile::Helpers }
#:startdoc:

require 'action_pack'
require 'action_view'

# ActionView::Base を拡張して携帯からのアクセスの場合に携帯向けビューを優先表示する。
# Vodafone携帯(request.mobile == Jpmobile::Mobile::Vodafone)の場合、
#   index_mobile_vodafone.html.erb
#   index_mobile_softbank.html.erb
#   index_mobile.html.erb
#   index.html.erb
# の順にテンプレートが検索される。
# BUG: 現状、上記の例では index.html.erb が存在しない場合に振り分けが行われない
# (ダミーファイルを置くことで回避可能)。

module ActionView
  class PathSet
    alias find_template_without_jpmobile find_template #:nodoc:
    alias initialize_without_jpmobile initialize #:nodoc:

    attr_accessor :controller, :mailer

    def initialize(*args)
      case args.first
      when ActionController::Base
        @controller = args.shift
      when ActionMailer::Base
        @mailer     = args.shift
      end

      initialize_without_jpmobile(*args)
    end

    # hook ActionView::PathSet#find_template
    def find_template(original_template_path, format = nil, html_fallback = true) #:nodoc:
      return original_template_path if original_template_path.respond_to?(:render)
      template_path = original_template_path.sub(/^\//, '')

      template_candidates = if controller.kind_of?(ActionController::Base)
                              mobile_template_candidates(controller)
                            elsif mailer.kind_of?(ActionMailer::Base)
                              mobile_mail_template_candidates(mailer)
                            else
                              []
                            end

      format_postfix      = format ? ".#{format}" : ""

      each do |load_path|
        template_candidates.each do |template_postfix|
          if template = load_path["#{template_path}_#{template_postfix}#{format_postfix}"]
            return template
          end
        end
      end

      return find_template_without_jpmobile(original_template_path, format, html_fallback)
    end

    # collect cadidates of mobile_template
    def mobile_template_candidates(controller)
      candidates = []

      return candidates unless controller.request.mobile?

      c = controller.request.mobile.class
      while c != Jpmobile::Mobile::AbstractMobile
        candidates << "mobile_" + c.to_s.split(/::/).last.downcase
        c = c.superclass
      end
      candidates << "mobile"
    end

    # collect candidates of mobile mail templates
    def mobile_mail_template_candidates(mailer)
      candidates = []

      # 複数アドレスの場合は選択しない
      if mailer.recipients.is_a?(String)
        if c = Jpmobile::Email.detect(mailer.recipients) and c != Jpmobile::Mobile::AbstractMobile
          candidates << "mobile_" + c.to_s.split(/::/).last.downcase
          candidates << "mobile"
        end
      end

      candidates
    end
  end

  class Base #:nodoc:
    delegate :default_url_options, :to => :controller unless respond_to?(:default_url_options)
    alias render_without_jpmobile render

    # nothing to do
    def view_paths=(paths)
      @view_paths = self.class.process_view_paths(paths, controller)
    end

    def self.process_view_paths(value, controller = nil)
      case controller
      when ActionController::Base, ActionMailer::Base
        ActionView::PathSet.new(controller, Array(value))
      else
        ActionView::PathSet.new(Array(value))
      end
    end

    def mobile_template_candidates
      candidates = []
      c = controller.request.mobile.class
      while c != Jpmobile::Mobile::AbstractMobile
        candidates << "mobile_"+c.to_s.split(/::/).last.downcase
        c = c.superclass
      end
      candidates << "mobile"
    end

    def mobile_template_partial mobile_path
      # ActionView::PartialTemplate#extract_partial_name_and_path の動作を模倣
      if mobile_path.include?('/')
        path = File.dirname(mobile_path)
        partial_name = File.basename(mobile_path)
      else
        path = self.controller.class.controller_path
        partial_name = mobile_path
      end
      File.join(path, "_#{partial_name}")
    end

    def mobile_path template_path, type
      "#{template_path}_#{type}"
    end

    def mobile_template_path(template_path, partial=false)
      if controller.is_a?(ActionController::Base) && m = controller.request.mobile
        mobile_template_candidates.each do |v|
          mpath = mobile_path template_path, v
          if partial
            full_path = mobile_template_partial mpath
          else
            full_path = mpath
          end
          if template_exists?(full_path)
            return mpath
          end
        end
      end
      return nil
    end
  end
end
