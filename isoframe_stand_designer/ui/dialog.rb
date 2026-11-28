# frozen_string_literal: true
# HtmlDialog panel. v0.1.45: register action callbacks BEFORE set_file, recreate
# the dialog when closed, and wrap callbacks so Ruby errors surface. SketchUp
# 2026 stopped invoking sketchup.* when callbacks were added after set_file on a
# cached dialog — every panel button looked dead.
#
# v0.1.81: product tabs (Wave / Fabric / Lumen / Ripple / ISObar / Express).
# Wave actions go through Products::Wave facade only.
# v0.1.82: Floorspace shared above tabs; Fabric place + edge-snap callbacks.
# v0.1.83: Fabric graphic covers entire Al frame; all Z ≥ floorspace top.
# v0.1.84: Fabric Frame Size dialog (replaces Edge Snap); bottom rear Al rail.
# v0.1.85: Fabric outer-to-outer width; bottom rail coplanar with posts/top.
# v0.1.86: braces; Place always 900×Midi (no stale resized def).
# v0.1.87: snap_width 900+k×250 (fixes 900→1000); Super-Maxi 4 braces.
# v0.1.89: Frame Size grows right; Fabric Join 90° + join post.

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
          preferences_key: 'ISOframeStandDesignerDialog_v0189',
          scrollable: true,
          resizable: true,
          width: 300,
          height: 740,
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

        # Shared floorspace (above tabs) — Floorspace module only, not product-owned.
        bind.call('run_floorspace') { Floorspace.prompt_and_draw! }

        # Wave tab — Products::Wave facade (firewall).
        bind.call('run_starter') { Products::Wave.run_starter! }
        bind.call('run_extension') { Products::Wave.run_extension! }
        bind.call('run_flex') { Products::Wave.run_flex! }
        bind.call('run_height') { Products::Wave.run_height! }
        bind.call('run_artwork') { Products::Wave.run_artwork! }
        bind.call('run_light_left') { Products::Wave.run_light_left! }
        bind.call('run_light_right') { Products::Wave.run_light_right! }
        bind.call('run_table_keyboard') { Products::Wave.run_table_keyboard! }
        bind.call('run_table_semi_circular') { Products::Wave.run_table_semi_circular! }
        bind.call('run_table_square') { Products::Wave.run_table_square! }
        bind.call('run_counter_oval') { Products::Wave.run_counter_oval! }
        bind.call('run_screen_small') { Products::Wave.run_screen_small! }
        bind.call('run_screen_large') { Products::Wave.run_screen_large! }

        # Fabric tab — Products::Fabric only (no Wave flex / no Edge Snap).
        bind.call('run_fabric_place') { Products::Fabric.run_place_midi! }
        bind.call('run_fabric_frame_size') { Products::Fabric.run_frame_size! }
        bind.call('run_fabric_join') { Products::Fabric.run_join! }
      end
    end
  end
end
