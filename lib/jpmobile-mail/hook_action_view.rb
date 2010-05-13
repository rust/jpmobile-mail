# -*- coding: utf-8 -*-
# = viewの自動切り替えのメール拡張
module ActionView
  class PathSet
    attr_accessor :mailer

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
    alias render_without_jpmobile render

    def self.process_view_paths(value, controller = nil)
      case controller
      when ActionController::Base, ActionMailer::Base
        ActionView::PathSet.new(controller, Array(value))
      else
        ActionView::PathSet.new(Array(value))
      end
    end
  end
end
