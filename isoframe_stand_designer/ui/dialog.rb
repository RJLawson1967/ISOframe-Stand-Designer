# frozen_string_literal: true
# HtmlDialog panel. v0.1.45: register action callbacks BEFORE set_file, recreate
# the dialog when closed, and wrap callbacks so Ruby errors surface. SketchUp
# 2026 stopped invoking sketchup.* when callbacks were added after set_file on a
# cached dialog — every panel button looked dead.

module ISOframe
  module StandDesigner
    module Dialog
      module_function

      def show!
        if @dialog && @dialog.visible?
          @dialog.bring_to_front
          return
        end
        # Closed / never-shown: rebuild so callbacks bind to a live dialog.
        begin
          @dialog.close if @dialog
        rescue StandardError
          nil
        end
        @dialog = build_dialog
        @dialog.show
      end

      def build_dialog
        dlg = UI::HtmlDialog.new(
          dialog_title: 'ISOframe Stand Designer',
          preferences_key: 'ISOframeStandDesignerDialog_v0145',
          scrollable: true,
          resizable: true,
          width: 210,
          height: 660,
          style: UI::HtmlDialog::STYLE_DIALOG
        )

        # CRITICAL: add_action_callback BEFORE set_file / show (SketchUp 2026).
        wire_callbacks!(dlg)

        html = File.join(File.dirname(__FILE__), 'dialog.html')
        dlg.set_file(html)
        dlg
      end

      def wire_callbacks!(dlg)
        bind = lambda do |name, &block|
          dlg.add_action_callback(name) do |*args|
            begin
              block.call(*args)
            rescue StandardError => e
              puts "[ISOframe] panel #{name} failed: #{e.message}"
              UI.messagebox("ISOframe panel action failed:\n#{e.message}")
            end
          end
        end

        bind.call('run_floorspace') { Floorspace.prompt_and_draw! }
        bind.call('run_starter') do
          Sketchup.active_model.select_tool(Tools::PlaceStarterTool.new)
        end
        bind.call('run_extension') do
          Sketchup.active_model.select_tool(Tools::PlaceExtensionTool.new)
        end
        bind.call('run_flex') do
          Sketchup.active_model.select_tool(Tools::FlexTool.new)
        end
        bind.call('run_height') { Tools::HeightSwap.swap_selected! }
        bind.call('run_artwork') { Artwork.prompt_and_add! }
        bind.call('run_light_left') { Tools::AddLight.toggle_selected!(:left) }
        bind.call('run_light_right') { Tools::AddLight.toggle_selected!(:right) }
        bind.call('run_table_keyboard') { Tools::AddTable.toggle_selected!('keyboard') }
        bind.call('run_table_semi_circular') { Tools::AddTable.toggle_selected!('semi_circular') }
        bind.call('run_table_square') { Tools::AddTable.toggle_selected!('square') }
        bind.call('run_counter_oval') { Counters.place_selected!('oval') }
        bind.call('run_screen_small') { Tools::AddScreen.toggle_selected!('small') }
        bind.call('run_screen_large') { Tools::AddScreen.toggle_selected!('large') }
      end
    end
  end
end
