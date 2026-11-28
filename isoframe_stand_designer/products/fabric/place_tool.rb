# frozen_string_literal: true
# Click floorspace to place a Fabric Midi starter (900 × 2270). No flex.

module ISOframe
  module StandDesigner
    module Products
      module Fabric
        class PlaceTool
          def activate
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
              'Fabric: click floorspace to place Midi starter (900 × 2270 mm). Esc cancels.'
          end

          def place_at(point)
            return unless License.require_active!
            return unless Floorspace.require_defined!
            model = Sketchup.active_model
            model.start_operation('Place Fabric Midi Starter', true)
            begin
              # Always 900 × Midi — never inherit a previously resized definition.
              width = Fabric::Constants::STARTER_WIDTH_MM
              height = Fabric::Constants::DEFAULT_HEIGHT
              Fabric::Geometry.purge_unused_fabric_defs!(model)
              defn = Fabric::Geometry.definition_for!(model, width, height)
              # definition_for! always rebuilds; attrs forced to starter defaults.
              origin = Geom::Point3d.new(point.x, point.y, Floorspace.module_base_z(model))
              tr = Fabric::Geometry.placement_transform(origin)
              inst = model.active_entities.add_instance(defn, tr)
              inst.name = Fabric::Constants::INSTANCE_NAME
              write_attrs!(inst, width, height)
              Constraints.mark_floor_slide!(inst)
              Constraints.snap_floor_sitting_to_floor!(inst)
              model.selection.clear
              model.selection.add(inst)
              Sketchup.status_text =
                'Fabric Midi 900×2270 placed — select it, then Frame Size to set height/width.'
              model.commit_operation
            rescue StandardError => e
              model.abort_operation
              UI.messagebox("Place Fabric failed:\n#{e.message}")
            end
          end

          def write_attrs!(inst, width, height)
            Attributes.set_many(inst, {
              ::ISOframe::StandDesigner::Constants::KEY_RANGE =>
                ::ISOframe::StandDesigner::Constants::RANGE_FABRIC,
              ::ISOframe::StandDesigner::Constants::KEY_TYPE =>
                ::ISOframe::StandDesigner::Constants::TYPE_FABRIC_WALL,
              ::ISOframe::StandDesigner::Constants::KEY_HEIGHT => height.to_s,
              ::ISOframe::StandDesigner::Constants::KEY_FABRIC_WIDTH_MM => width.to_f,
              ::ISOframe::StandDesigner::Constants::KEY_FLOOR_SLIDE => '1',
              ::ISOframe::StandDesigner::Constants::KEY_FLEX => 0.0
            })
          end
        end
      end
    end
  end
end
