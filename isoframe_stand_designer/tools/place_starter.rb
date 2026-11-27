# frozen_string_literal: true
module ISOframe
  module StandDesigner
    module Tools
      class PlaceStarterTool
        def activate
          @height = Constants::DEFAULT_HEIGHT
          @ip = Sketchup::InputPoint.new
          update_status
        end

        def deactivate(view)
          view.invalidate
        end

        def resume(view)
          update_status
          view.invalidate
        end

        def onCancel(_reason, view)
          view.invalidate
        end

        def onMouseMove(_flags, x, y, view)
          @ip.pick(view, x, y)
          view.tooltip = @ip.tooltip if @ip.valid?
          view.invalidate
        end

        def onLButtonDown(_flags, x, y, view)
          @ip.pick(view, x, y)
          return unless @ip.valid?
          place_at(@ip.position)
          view.invalidate
        end

        def draw(view)
          return unless @ip && @ip.valid?
          view.draw_points([@ip.position], 8, 2, 'blue')
        end

        def getExtents
          bb = Geom::BoundingBox.new
          bb.add(@ip.position) if @ip && @ip.valid?
          bb
        end

        private

        def update_status
          Sketchup.status_text =
            'ISOframe: click to place Wave Starter (2 posts + beam). Esc to cancel.'
          Sketchup.vcb_label = 'Height'
          Sketchup.vcb_value = @height
        end

        def place_at(point)
          return unless License.require_active!
          return unless Floorspace.require_defined!
          model = Sketchup.active_model
          model.start_operation('Place Wave Starter', true)
          begin
            defn = Geometry.definition_for(model, Constants::TYPE_STARTER, @height)
            # Foot sole on floor top when floorspace exists (else ground Z=0).
            origin = Geom::Point3d.new(point.x, point.y, Floorspace.module_base_z(model))
            # RH ψ=180°: graphic faces floorspace (−Y). Local free → world −X
            # (viewer left); Place Extension grows from hinge tip (viewer right).
            tr = Geometry.starter_placement_transform(origin)
            inst = model.active_entities.add_instance(defn, tr)
            wall_id = "wall_#{Time.now.to_i}_#{rand(1000..9999)}"
            Attributes.write_module(
              inst,
              type: Constants::TYPE_STARTER,
              height: @height,
              wall_id: wall_id,
              flex_angle: 0.0
            )
            WallGraph.write_starter_graph!(inst)
            Constraints.ensure_module_on_floor!(inst) # floor-slide: feet on floorspace top
            model.selection.clear
            model.selection.add(inst)
            Sketchup.status_text =
              "Placed Starter — wall #{wall_id}. Slides on floor (Z locked). " \
              "#{WallMath.status_line_for_wall(model, wall_id)}"
            model.commit_operation
          rescue StandardError => e
            model.abort_operation
            UI.messagebox("Place Starter failed: #{e.message}")
          end
        end
      end
    end
  end
end
