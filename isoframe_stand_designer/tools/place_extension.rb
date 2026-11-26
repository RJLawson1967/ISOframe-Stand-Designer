# frozen_string_literal: true
# Place Extension — attach at the wall's graphic-front RIGHT tip (continue end).
# Starter Place uses RH ψ=180° so the graphic faces floorspace; local free maps
# to world −X (viewer LEFT). Continue tip is therefore the hinge/root end
# (viewer RIGHT). Open-end selection only — no plan-mirror Place.
module ISOframe
  module StandDesigner
    module Tools
      class PlaceExtensionTool
        def activate
          @height = Constants::DEFAULT_HEIGHT
          seed = find_seed_instance
          unless seed
            UI.messagebox(
              "Select a Wave starter or extension,\n" \
              'then run Place Extension again.'
            )
            Sketchup.active_model.select_tool(nil)
            return
          end
          tip = WallGraph.place_continue_tip(seed)
          unless tip && tip[:module] && tip[:module].valid?
            UI.messagebox('Could not find the open (continue) end of that wall.')
            Sketchup.active_model.select_tool(nil)
            return
          end
          @anchor = tip[:module]
          @attach_side = tip[:side]
          @ip = Sketchup::InputPoint.new
          update_status
        end

        def deactivate(view)
          view.invalidate
        end

        def onCancel(_reason, view)
          view.invalidate
        end

        def onMouseMove(_flags, x, y, view)
          @ip.pick(view, x, y)
          view.invalidate
        end

        def onLButtonDown(_flags, x, y, view)
          place_extension!
          view.invalidate
        end

        def draw(view)
          return unless @anchor && @anchor.valid?
          open_pt = Geometry.world_continue_end(@anchor, @attach_side)
          view.drawing_color = 'green'
          view.draw_points([open_pt], 10, 2, 'green')
          right = Geometry.graphic_front_right_vector(@anchor)
          tip = open_pt.offset(right, Constants::GRAPHIC_BAY_MM.mm)
          view.line_stipple = '_'
          view.draw_line(open_pt, tip)
        end

        def getExtents
          bb = Geom::BoundingBox.new
          if @anchor && @anchor.valid?
            bb.add(Geometry.world_continue_end(@anchor, @attach_side))
          end
          bb
        end

        private

        def update_status
          wid = Attributes.get(@anchor, Constants::KEY_WALL)
          open_pt = Geometry.world_continue_end(@anchor, @attach_side)
          Sketchup.status_text =
            "ISOframe: click to attach Extension at the open (right/continue) end of wall #{wid} " \
            "(snap #{format_open_pt(open_pt)}). Esc cancels."
        end

        def format_open_pt(pt)
          return '?' unless pt
          format('world open X=%d Y=%d mm', (pt.x.to_f * 25.4).round, (pt.y.to_f * 25.4).round)
        end

        def find_seed_instance
          sel = Sketchup.active_model.selection
          sel.grep(Sketchup::ComponentInstance).find do |inst|
            type = Attributes.get(inst, Constants::KEY_TYPE)
            type == Constants::TYPE_STARTER || type == Constants::TYPE_EXTENSION
          end
        end

        def place_extension!
          return unless License.require_active!
          return unless Floorspace.require_defined!
          return unless @anchor && @anchor.valid?
          model = Sketchup.active_model
          wall_id = Attributes.get(@anchor, Constants::KEY_WALL)
          @height = Attributes.get(@anchor, Constants::KEY_HEIGHT, Constants::DEFAULT_HEIGHT)
          side = @attach_side || Geometry.module_continue_end_side(@anchor)
          open_before = Geometry.world_continue_end(@anchor, side)
          model.start_operation('Place Wave Extension', true)
          begin
            defn = Geometry.definition_for(model, Constants::TYPE_EXTENSION, @height)
            tr = Geometry.world_extension_placement(@anchor, side)
            inst = model.active_entities.add_instance(defn, tr)
            Attributes.write_module(
              inst,
              type: Constants::TYPE_EXTENSION,
              height: @height,
              wall_id: wall_id,
              flex_angle: 0.0
            )
            WallGraph.write_extension_graph!(inst, @anchor, side: side)
            Artwork.reapply_wall!(model, wall_id) if Artwork.wall_has_artwork?(model, wall_id)
            Constraints.ensure_module_on_floor!(inst)
            Constraints.ensure_module_on_floor!(@anchor) if @anchor && @anchor.valid?
            model.selection.clear
            model.selection.add(inst)
            tip_after = WallGraph.place_continue_tip(inst)
            open_after = if tip_after && tip_after[:module]
                           Geometry.world_continue_end(tip_after[:module], tip_after[:side])
                         else
                           Geometry.world_continue_end(inst, side)
                         end
            Sketchup.status_text =
              "#{WallMath.status_line_for_wall(model, wall_id)} — " \
              "Place snapped to #{format_open_pt(open_before)}; new open #{format_open_pt(open_after)}."
            model.commit_operation
            if tip_after && tip_after[:module] && tip_after[:module].valid?
              @anchor = tip_after[:module]
              @attach_side = tip_after[:side]
            else
              @anchor = inst
              @attach_side = Geometry.module_continue_end_side(inst)
            end
            update_status
          rescue StandardError => e
            model.abort_operation
            UI.messagebox("Place Extension failed: #{e.message}")
          end
        end
      end
    end
  end
end
