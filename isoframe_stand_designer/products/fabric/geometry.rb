# frozen_string_literal: true
# Procedural Fabric wall (v0.1.82) — 37mm Al posts + fabric graphic. No flex.
# Does not call Wave Geometry rebuild / flex path.

module ISOframe
  module StandDesigner
    module Products
      module Fabric
        module Geometry
          module_function

          C = Products::Fabric::Constants

          def height_mm(height_key)
            C::HEIGHTS_MM[height_key.to_s] || C::HEIGHTS_MM[C::DEFAULT_HEIGHT]
          end

          def post_tip_mm(height_key)
            g = height_mm(height_key)
            C::GRAPHIC_Z_BOT_MM + g - C::GRAPHIC_TOP_ABOVE_POST_MM
          end

          def snap_width_mm(raw_mm)
            w = raw_mm.to_f
            w = C::STARTER_WIDTH_MM if w < C::STARTER_WIDTH_MM
            step = C::WIDTH_STEP_MM
            snapped = (w / step).round * step
            snapped = C::STARTER_WIDTH_MM if snapped < C::STARTER_WIDTH_MM
            snapped = 50_000.0 if snapped > 50_000.0
            snapped.to_f
          end

          def snap_height_key(raw_mm)
            h = raw_mm.to_f
            best = C::DEFAULT_HEIGHT
            best_d = 1.0e12
            C::HEIGHT_SNAP_ORDER.each do |key|
              d = (C::HEIGHTS_MM[key] - h).abs
              if d < best_d
                best_d = d
                best = key
              end
            end
            best
          end

          # 900 + greedy pack of 1000/750/500/250 covering (width − 900).
          def decompose_width_mm(total_mm)
            total = snap_width_mm(total_mm)
            rem = (total - C::STARTER_WIDTH_MM).round
            segs = [C::STARTER_WIDTH_MM]
            C::EXTENSION_WIDTHS_MM.each do |piece|
              piece_i = piece.round
              while rem >= piece_i
                segs << piece
                rem -= piece_i
              end
            end
            segs
          end

          def placement_transform(origin)
            # Same RH ψ=180° convention as Wave: graphic +Y faces floorspace (−world Y).
            Geom::Transformation.new(
              Geom::Vector3d.new(-1, 0, 0),
              Geom::Vector3d.new(0, -1, 0),
              Geom::Vector3d.new(0, 0, 1),
              origin
            )
          end

          def definition_name(width_mm, height_key)
            "#{C::DEFN_PREFIX} #{height_key} w#{width_mm.round}"
          end

          def definition_for!(model, width_mm, height_key)
            width = snap_width_mm(width_mm)
            hkey = height_key.to_s
            hkey = C::DEFAULT_HEIGHT unless C::HEIGHTS_MM.key?(hkey)
            name = definition_name(width, hkey)
            existing = model.definitions[name]
            if existing && !existing.image? && existing.entities.size > 0
              return existing
            end
            defn = existing || model.definitions.add(name)
            rebuild!(defn, width, hkey)
            defn
          end

          def rebuild!(defn, width_mm, height_key)
            defn.entities.clear! if defn.entities.size > 0
            width = snap_width_mm(width_mm)
            hkey = height_key.to_s
            segs = decompose_width_mm(width)
            tip = post_tip_mm(hkey)
            g_h = height_mm(hkey)
            z_bot = C::GRAPHIC_Z_BOT_MM.mm
            z_top = (C::GRAPHIC_Z_BOT_MM + g_h).mm

            xs = [0.0]
            segs.each { |s| xs << (xs.last + s) }
            xs.each_with_index do |x_mm, i|
              add_post!(defn.entities, x_mm.mm, tip, "#{C::GROUP_POST}_#{i}")
            end
            (0...(xs.size - 1)).each do |i|
              add_graphic_panel!(
                defn.entities,
                xs[i].mm,
                xs[i + 1].mm,
                z_bot,
                z_top,
                "#{C::GROUP_GRAPHIC}_#{i}"
              )
            end
            defn
          end

          def add_post!(ents, x, tip_mm, name)
            half = C::HALF_POST_MM.mm
            tip = tip_mm.mm
            pts = [
              Geom::Point3d.new(x - half, -half, 0),
              Geom::Point3d.new(x + half, -half, 0),
              Geom::Point3d.new(x + half, half, 0),
              Geom::Point3d.new(x - half, half, 0)
            ]
            group = ents.add_group
            group.name = name
            face = group.entities.add_face(pts)
            face.pushpull(tip) if face
            color = Sketchup::Color.new(*C::POST_RGB)
            group.entities.grep(Sketchup::Face).each do |f|
              f.material = color
              f.back_material = color
            end
          end

          def add_graphic_panel!(ents, x0, x1, z_bot, z_top, name)
            # Front face at +Y (post front); thickness along +Y (room side).
            y0 = C::HALF_POST_MM.mm + C::GRAPHIC_FRONT_CLEARANCE_MM.mm
            y1 = y0 + C::GRAPHIC_THICKNESS_MM.mm
            inset = C::HALF_POST_MM.mm
            xa = x0 + inset
            xb = x1 - inset
            return if xb <= xa
            # Bottom face then pushpull up for a solid slab.
            pts = [
              Geom::Point3d.new(xa, y0, z_bot),
              Geom::Point3d.new(xb, y0, z_bot),
              Geom::Point3d.new(xb, y1, z_bot),
              Geom::Point3d.new(xa, y1, z_bot)
            ]
            group = ents.add_group
            group.name = name
            face = group.entities.add_face(pts)
            return unless face
            height = z_top - z_bot
            face.pushpull(height) if height > 0
            color = Sketchup::Color.new(*C::GRAPHIC_RGB)
            group.entities.grep(Sketchup::Face).each do |f|
              f.material = color
              f.back_material = color
            end
          rescue StandardError => e
            puts "[ISOframe][Fabric] add_graphic_panel! failed: #{e.message}"
          end

          # World bounds helpers for edge-snap.
          def wall_local_width_mm(inst)
            Attributes.get(inst, ::ISOframe::StandDesigner::Constants::KEY_FABRIC_WIDTH_MM, C::STARTER_WIDTH_MM).to_f
          end

          def wall_height_key(inst)
            Attributes.get(inst, ::ISOframe::StandDesigner::Constants::KEY_HEIGHT, C::DEFAULT_HEIGHT).to_s
          end
        end
      end
    end
  end
end
