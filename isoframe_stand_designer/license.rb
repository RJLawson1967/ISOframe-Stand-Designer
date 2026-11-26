# frozen_string_literal: true
# Stub license gate for MVP. Accept any non-empty key; remember via Sketchup.write_default.

module ISOframe
  module StandDesigner
    module License
      module_function

      def active?
        Sketchup.read_default(Constants::PREFS_SECTION, Constants::PREFS_LICENSE_OK, false)
      end

      def stored_key
        Sketchup.read_default(Constants::PREFS_SECTION, Constants::PREFS_LICENSE_KEY, '') || ''
      end

      def activate!(key)
        key = key.to_s.strip
        return false if key.empty?
        Sketchup.write_default(Constants::PREFS_SECTION, Constants::PREFS_LICENSE_KEY, key)
        Sketchup.write_default(Constants::PREFS_SECTION, Constants::PREFS_LICENSE_OK, true)
        true
      end

      def deactivate!
        Sketchup.write_default(Constants::PREFS_SECTION, Constants::PREFS_LICENSE_OK, false)
      end

      def require_active!
        return true if active?
        input = UI.inputbox(['License key'], [stored_key], 'ISOframe License')
        return false unless input
        unless activate!(input[0])
          UI.messagebox('Enter a license key to continue (MVP accepts any non-empty key).')
          return false
        end
        true
      end

      def prompt_and_set!
        input = UI.inputbox(
          ['License key', 'Active (yes/no)'],
          [stored_key, active? ? 'yes' : 'no'],
          'ISOframe License'
        )
        return unless input
        key, flag = input
        if flag.to_s.downcase.start_with?('y')
          activate!(key)
          UI.messagebox('License marked active.')
        else
          deactivate!
          UI.messagebox('License deactivated.')
        end
      end
    end
  end
end
