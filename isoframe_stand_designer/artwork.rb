# frozen_string_literal: true
# Unified graphic wallpaper across a wall's GraphicHint fronts.
#
# v0.1.35+: Do NOT rely on position_material alone (soft loft facets often fail and
# SketchUp then fits the *full* texture on every bay → visible repeats). Instead:
#   - Crop the source image per bay (ImageRep) so bay i's material *is* slice i/n.
#   - Texture size = one bay width × height (default planar fit = correct slice).
#   - Optional path UV still tried for curved alignment (u within the bay crop).
# v0.1.36: Image load copies to a temp path without spaces; `.jpeg` → `.jpg` temp
# so Desktop folders like "ISOframe Stand Designer" never break ImageRep.
# Pure math helpers bay_u_window / bay_pixel_window are unit-tested without SketchUp.
# v0.1.59: wall wallpaper FRONT faces only (rear toward flex-link unpainted).
# Keyboard apron: lip-only faces under 15mm top + continuous cylindrical UV
# (fixes ~146k per-face tiling).
# v0.1.60: lip IS the apron (top is separate SKP). Stop Z-span≤17mm filter that
# zeroed tessellated lip facets; keep continuous UV + wall front-only.
# v0.1.61: table apron — bake-root transform + never-empty lip/safe fallback.
# Wall — restore v0.1.58 texture/UV paint path; clear rear faces after (front
# photo, rear plain). v0.1.59 outward-only + back_material=nil caused solid
# light-blue both sides.
# v0.1.62: table apron lip-only — exclude tabletop (all faces) and 37mm beams.
# v0.1.63: lip name often NONE (Boss-Extrude children) — geometric apron recovery.
# Wall — front wallpaper only; reverse of front faces + rear slab get panel
# plain tint (Geometry::GRAPHIC_PLAIN_RGB), never wallpaper and never nil
# (nil → SketchUp default light-blue).
# v0.1.64: CRITICAL — v0.1.63 plain Color on back_material made wall texture
# invisible (same class of failure as v0.1.59 nil). Restore v0.1.58/61 paint
# (wallpaper on BOTH sides of FRONT faces) so Apply Artwork is visible again;
# then force rear *slab* faces to a named plain Material (not nil, not empty).
# Table apron: never-empty geometric fallback when lip=NONE; opaque both sides
# + soft/smooth/hide edges so wrap front is line-free and posts don't show through.
# v0.1.65: paint target is Keyboard_table_graphic_wrap.skp /
# Graphic Keyboard Attachment (Rolable) — FRONT only, continuous UV, soft/hide.
# v0.1.66: 2500 faces "applied" but texture invisible — use wall-style planar UV,
# texture.size from wrap bounds, paint correct face side, soft+smooth without
# hide (hide was blanking the textured front).
# v0.1.67: “2500 faces” was apron fallback. Remove it. Table wrap now calls the
# same ensure_* texture + paint_front_face! path as wall wallpaper; make_unique
# nested defs; prove face.material.texture non-nil; dialog reports tex size.

module ISOframe
  module StandDesigner
    module Artwork
      module_function

      IMAGE_FILTER = 'Image Files|*.jpg;*.jpeg;*.png;*.tif;*.tiff;*.JPG;*.JPEG;*.PNG;*.TIF;*.TIFF||'
      MIN_FRONT_AREA_MM2 = 400.0
      MIN_TRI_AREA_IN2 = 1.0e-6
      MIN_UV_AREA = 1.0e-8

      # --- Pure math (no SketchUp). U window of bay i in a strip of width tex_w. ---
      # Returns [u0, u1] in the same units as tex_w. Bay 0 → [0, tex_w/n]; last →
      # nearly [tex_w, tex_w]. Never returns a full [0, tex_w] for n > 1.
      def bay_u_window(bay_index, bay_count, tex_w = 1.0)
        n = [bay_count.to_i, 1].max
        i = bay_index.to_i
        i = 0 if i < 0
        i = n - 1 if i >= n
        w = tex_w.to_f
        u0 = (i.to_f / n) * w
        u1 = ((i + 1).to_f / n) * w
        [u0, u1]
      end

      # Pixel crop window [x0, x1) for bay i of an image width `px_w` (exclusive end).
      def bay_pixel_window(bay_index, bay_count, px_w)
        n = [bay_count.to_i, 1].max
        i = bay_index.to_i
        i = 0 if i < 0
        i = n - 1 if i >= n
        w = [px_w.to_i, 1].max
        x0 = ((i.to_f / n) * w).floor
        x1 = (((i + 1).to_f / n) * w).floor
        x1 = x0 + 1 if x1 <= x0
        x1 = w if x1 > w
        [x0, x1]
      end

      def prompt_and_apply!
        return unless License.require_active!
        model = Sketchup.active_model
        seed = selected_wave_module(model)
        unless seed
          UI.messagebox(
            "Select any Wave starter or extension on the wall,\n" \
            'then choose Apply Artwork… again.'
          )
          return false
        end
        wall_id = Attributes.get(seed, Constants::KEY_WALL).to_s
        if wall_id.empty?
          UI.messagebox('That module has no wall id.')
          return false
        end
        path = UI.openpanel('Choose artwork image', '', IMAGE_FILTER)
        return false if path.nil? || path.to_s.strip.empty?
        path = normalize_image_path(path)
        unless path && File.file?(path)
          UI.messagebox("File not found:\n#{path}")
          return false
        end
        apply_to_wall!(model, wall_id, path)
      end

      def wall_has_artwork?(model, wall_id)
        WallGraph.modules_on_wall(model, wall_id).any? do |inst|
          p = Attributes.get(inst, Constants::KEY_ARTWORK_PATH).to_s
          !p.empty?
        end
      end

      def artwork_path_for_wall(model, wall_id)
        WallGraph.modules_on_wall(model, wall_id).each do |inst|
          p = Attributes.get(inst, Constants::KEY_ARTWORK_PATH).to_s
          return p unless p.empty?
        end
        nil
      end

      def apply_to_wall!(model, wall_id, image_path)
        mods = WallGraph.ordered_wall_modules(model, wall_id)
        if mods.empty?
          UI.messagebox('No Wave modules on that wall.')
          return false
        end
        image_path = normalize_image_path(image_path)
        unless image_path && File.file?(image_path)
          UI.messagebox("File not found:\n#{image_path}")
          return false
        end
        model.start_operation('ISOframe Apply Artwork', true)
        begin
          n = mods.size
          height_mm = height_mm_for(mods.first)
          source = load_source_rep!(image_path)
          painted = 0
          mods.each_with_index do |inst, i|
            Attributes.set(inst, Constants::KEY_ARTWORK_PATH, image_path.to_s)
            mat = ensure_bay_material!(model, wall_id, i, n, source, image_path, height_mm)
            painted += map_instance!(inst, mat, i, n, height_mm)
          end
          if painted <= 0
            raise 'No graphic front faces found to paint. Try selecting the wall module again.'
          end
          model.commit_operation
          total_w_mm = n * Constants::GRAPHIC_BAY_MM
          msg = "Artwork applied as one #{total_w_mm.to_i} mm strip across #{n} bay#{n == 1 ? '' : 's'} " \
                "(#{painted} face#{painted == 1 ? '' : 's'}; cropped per bay)."
          Sketchup.status_text = msg
          UI.messagebox(msg)
          true
        rescue StandardError => e
          model.abort_operation
          msg = e.message.to_s
          if msg =~ /matrix|position_material|UV map failed/i
            msg = 'Could not paint graphic faces. Try again with the wall module selected.'
          end
          UI.messagebox("Apply Artwork failed:\n#{msg}")
          false
        end
      end

      def reapply_wall!(model, wall_id)
        path = artwork_path_for_wall(model, wall_id)
        return false if path.nil? || path.empty?
        path = normalize_image_path(path)
        return false unless path && File.file?(path)
        mods = WallGraph.ordered_wall_modules(model, wall_id)
        return false if mods.empty?
        n = mods.size
        height_mm = height_mm_for(mods.first)
        source = load_source_rep!(path)
        mods.each_with_index do |inst, i|
          Attributes.set(inst, Constants::KEY_ARTWORK_PATH, path.to_s)
          mat = ensure_bay_material!(model, wall_id, i, n, source, path, height_mm)
          map_instance!(inst, mat, i, n, height_mm)
        end
        true
      rescue StandardError
        false
      end

      def reapply_after_rebuild!(inst)
        return unless inst && inst.valid?
        path = Attributes.get(inst, Constants::KEY_ARTWORK_PATH).to_s
        return if path.empty?
        path = normalize_image_path(path)
        return unless path && File.file?(path)
        wall_id = Attributes.get(inst, Constants::KEY_WALL)
        mods = WallGraph.ordered_wall_modules(inst.model, wall_id)
        idx = mods.index(inst)
        return if idx.nil?
        n = mods.size
        height_mm = height_mm_for(inst)
        source = load_source_rep!(path)
        mat = ensure_bay_material!(inst.model, wall_id, idx, n, source, path, height_mm)
        map_instance!(inst, mat, idx, n, height_mm)
      rescue StandardError
        nil
      end

      # --- Under-table graphic (separate from wall wallpaper) -----------------
      # Wall Apply Artwork only paints Wave GraphicHint groups. Table artwork
      # paints TableGraphicHint / Graphic Keyboard Attachment on the sibling
      # keyboard table instance only.

      def prompt_and_apply_table!
        return unless License.require_active!
        model = Sketchup.active_model
        table = selected_table_instance(model)
        host = nil
        unless table
          host = selected_wave_module(model)
          table = Tables.find_table_instance_for_host(host) if host && Tables.table_on?(host)
        end
        unless table && table.valid?
          UI.messagebox(
            "Select a Keyboard Table (or its Wave module),\n" \
            'then choose Apply Table Artwork… again.'
          )
          return false
        end
        host ||= Tables.host_for_table(table)
        path = UI.openpanel('Choose under-table artwork image', '', IMAGE_FILTER)
        return false if path.nil? || path.to_s.strip.empty?
        path = normalize_image_path(path)
        unless path && File.file?(path)
          UI.messagebox("File not found:\n#{path}")
          return false
        end
        apply_to_table!(table, host, path)
      end

      def apply_to_table!(table_inst, host, image_path)
        model = table_inst.model
        image_path = normalize_image_path(image_path)
        unless image_path && File.file?(image_path)
          UI.messagebox("File not found:\n#{image_path}")
          return false
        end
        model.start_operation('ISOframe Apply Table Artwork', true)
        begin
          Attributes.set(table_inst, Constants::KEY_TABLE_ARTWORK_PATH, image_path.to_s)
          Attributes.set(host, Constants::KEY_TABLE_ARTWORK_PATH, image_path.to_s) if host && host.valid?
          painted = map_table_instance!(table_inst, image_path)
          if painted <= 0
            raise 'No graphic wrap faces found to paint.'
          end
          model.commit_operation
          rep = @last_table_paint_report || {}
          tex_sz = rep[:texture_size]
          tex_s = if tex_sz.is_a?(Array) && tex_sz.size >= 2
                    format('%.1f×%.1f mm', tex_sz[0].to_f * 25.4, tex_sz[1].to_f * 25.4)
                  else
                    tex_sz.inspect
                  end
          msg = "Table artwork applied (#{painted} face#{painted == 1 ? '' : 's'}; " \
                "textured=#{rep[:textured] || '?'}; material=#{rep[:material] || '?'}; " \
                "texture size=#{tex_s}). Wall wallpaper is unchanged."
          Sketchup.status_text = msg
          UI.messagebox(msg)
          true
        rescue StandardError => e
          model.abort_operation
          UI.messagebox("Apply Table Artwork failed:\n#{e.message}")
          false
        end
      end

      def reapply_table_instance!(table_inst)
        return unless table_inst && table_inst.valid?
        path = Attributes.get(table_inst, Constants::KEY_TABLE_ARTWORK_PATH, '').to_s
        return if path.empty?
        path = normalize_image_path(path)
        return unless path && File.file?(path)
        map_table_instance!(table_inst, path)
      rescue StandardError
        nil
      end

      def reapply_table_after_rebuild!(host)
        return unless host && host.valid?
        table = Tables.find_table_instance_for_host(host)
        return unless table
        path = Attributes.get(table, Constants::KEY_TABLE_ARTWORK_PATH, '').to_s
        path = Attributes.get(host, Constants::KEY_TABLE_ARTWORK_PATH, '').to_s if path.empty?
        return if path.empty?
        Attributes.set(table, Constants::KEY_TABLE_ARTWORK_PATH, path)
        reapply_table_instance!(table)
      rescue StandardError
        nil
      end

      def selected_table_instance(model)
        model.selection.grep(Sketchup::ComponentInstance).find do |inst|
          Tables.table_instance?(inst)
        end
      end

      def map_table_instance!(table_inst, image_path)
        return 0 unless table_inst && table_inst.valid?
        @last_table_paint_report = nil
        defn = table_inst.definition
        begin
          if table_inst.respond_to?(:make_unique) && defn.count_instances.to_i > 1
            table_inst.make_unique
            defn = table_inst.definition
          end
        rescue StandardError
          nil
        end

        # v0.1.67: Graphic Keyboard wrap ONLY — never fall back to apron dump.
        Tables.purge_synthetic_table_graphic_panels!(defn)
        Tables.mark_table_graphic_targets!(defn)
        wrap, _wrap_tr = Tables.ensure_graphic_wrap_target!(defn, table_inst.model)
        unless wrap && wrap.valid?
          dump = Tables.dump_baked_entity_names(defn.entities, 0)
          raise 'No Graphic Keyboard Attachment (Rolable) wrap found. ' \
                'Toggle Keyboard Table off/on once (v67 bake), then try again. ' \
                "bake=#{dump}"
        end

        prep = Tables.prepare_graphic_wrap_for_paint!(wrap)
        unless prep && prep[:faces] && !prep[:faces].empty?
          raise 'Graphic wrap has no outward front faces to paint. ' \
                'Toggle Keyboard Table off/on (v67), then try again.'
        end
        faces = prep[:faces]
        if faces.size > 500
          raise "Graphic wrap face filter too broad (#{faces.size}). Expected wrap front only."
        end

        mid = Attributes.get(table_inst, Constants::KEY_TABLE_HOST, 'table').to_s
        source = load_source_rep!(image_path)
        # SAME as wall: load texture + set_texture_size so default fit shows photo.
        mat = ensure_wrap_material_like_wall!(
          table_inst.model, mid, source, image_path, prep[:width_mm], prep[:height_mm]
        )
        unless mat && mat.texture
          raise 'Wrap material has no texture after load (wall-style ensure failed).'
        end

        painted = map_wrap_faces_like_wall!(faces, mat, prep[:path_local], prep[:height_mm])
        textured = count_faces_with_texture(faces)
        if textured <= 0
          raise 'Paint ran but face.material.texture is nil on wrap fronts. ' \
                'Material may be on a shared nested definition — report to support.'
        end

        @last_table_paint_report = {
          faces: painted,
          textured: textured,
          material: mat.name.to_s,
          texture_size: (mat.texture.size rescue nil)
        }
        puts "[ISOframe] Table wrap WALL-PATH painted=#{painted} textured=#{textured} " \
             "mat=#{mat.name} tex=#{@last_table_paint_report[:texture_size].inspect}"
        painted
      end

      # Wall-identical material load: texture from file/ImageRep + texture.size in mm.
      def ensure_wrap_material_like_wall!(model, table_key, source, image_path, width_mm, height_mm)
        name = "ISOframe Table Artwork #{table_key}"
        mat = model.materials[name]
        mat ||= model.materials.add(name)
        begin
          mat.color = Sketchup::Color.new(255, 255, 255)
          mat.alpha = 1.0 if mat.respond_to?(:alpha=)
        rescue StandardError
          nil
        end

        w_mm = [width_mm.to_f, 10.0].max
        h_mm = [height_mm.to_f, 10.0].max
        loaded = false
        rep = source.is_a?(Hash) ? source[:rep] : nil
        # Full image (wrap is one panel, not a bay crop) — same texture= assignment as wall.
        if rep && defined?(Sketchup::ImageRep)
          begin
            mat.texture = rep
            loaded = !mat.texture.nil?
          rescue StandardError
            loaded = false
          end
        end
        unless loaded
          path = source.is_a?(Hash) ? source[:path] : nil
          path = safe_image_load_path(normalize_image_path(image_path)) if path.nil? || !File.file?(path.to_s)
          if path && File.file?(path)
            begin
              mat.texture = path
              loaded = !mat.texture.nil?
            rescue StandardError
              loaded = false
            end
          end
        end
        unless loaded
          begin
            mat.texture = image_path
            loaded = !mat.texture.nil?
          rescue StandardError
            loaded = false
          end
        end
        raise 'SketchUp could not load wrap texture (wall-style)' unless loaded

        begin
          if rep && rep.width.to_i > 0 && rep.height.to_i > 0
            aspect = rep.height.to_f / rep.width.to_f
            h_mm = [h_mm, w_mm * aspect].max
          end
        rescue StandardError
          nil
        end
        set_texture_size!(mat, w_mm, h_mm)
        raise 'Wrap material.texture nil after set_texture_size' if mat.texture.nil?
        mat
      end

      # Paint wrap fronts with the proven wall paint_front_face! helper.
      def map_wrap_faces_like_wall!(faces, material, path, height_mm)
        return 0 if faces.nil? || faces.empty? || material.nil?
        path ||= [
          Geom::Point3d.new(0, 0, 0),
          Geom::Point3d.new(Constants::GRAPHIC_BAY_MM.mm, 0, 0)
        ]
        tex_w, tex_h = texture_dims(material, Constants::GRAPHIC_BAY_MM.mm, height_mm.to_f.mm)
        u0 = 0.0
        u1 = tex_w
        h = tex_h
        cum = path_cumulative_lengths(path)
        total = cum.empty? ? 0.0 : cum.last
        total = tex_w if total < 1e-9

        painted = 0
        faces.each do |face|
          next unless face && face.valid?
          painted += 1 if paint_front_face!(face, material, u0, u1, h, path, cum, total)
        end
        soften_smooth_graphic_front_edges!(faces)
        painted
      end

      def count_faces_with_texture(faces)
        n = 0
        faces.each do |f|
          next unless f && f.valid?
          m = f.material
          n += 1 if m && m.respond_to?(:texture) && m.texture
        rescue StandardError
          nil
        end
        n
      end

      # Legacy name — redirects to wall-style ensure (kept for older tests).
      def ensure_table_wrap_material!(model, table_key, image_path, source, faces)
        prep_w = Constants::GRAPHIC_BAY_MM
        prep_h = 400.0
        begin
          w, h, _p = Tables.wrap_uv_path_from_faces(faces)
          prep_w = w
          prep_h = h
        rescue StandardError
          nil
        end
        ensure_wrap_material_like_wall!(model, table_key, source, image_path, prep_w, prep_h)
      end

      # Legacy paint entry — now wall path.
      def paint_graphic_wrap_front!(faces, material, view_dir = nil, face_tr = nil)
        _ = view_dir
        _ = face_tr
        return 0 unless material && material.texture
        w_mm = Constants::GRAPHIC_BAY_MM
        h_mm = 400.0
        path = nil
        begin
          w_mm, h_mm, path = Tables.wrap_uv_path_from_faces(faces)
        rescue StandardError
          nil
        end
        map_wrap_faces_like_wall!(faces, material, path, h_mm)
      end

      # Texture sized to the developed apron (one image across the curve).
      def ensure_table_apron_material!(model, table_key, image_path, source, apron_faces)
        name = "ISOframe Table Artwork #{table_key}"
        mat = model.materials[name] || model.materials.add(name)
        begin
          mat.color = Sketchup::Color.new(255, 255, 255)
          mat.alpha = 1.0 if mat.respond_to?(:alpha=)
        rescue StandardError
          nil
        end
        load_path = source.is_a?(Hash) ? source[:path] : nil
        load_path = safe_image_load_path(normalize_image_path(image_path)) if load_path.nil? || !File.file?(load_path.to_s)
        begin
          mat.texture = load_path
        rescue StandardError
          mat.texture = image_path
        end
        raise 'SketchUp could not load under-table texture' if mat.texture.nil?

        width_mm, height_mm = apron_developed_size_mm(apron_faces, source)
        set_texture_size!(mat, width_mm, height_mm)
        mat
      end

      # Planar UV frame for the nearly-flat 3-panel wrap (U = width, V = height).
      def wrap_planar_uv_frame(faces)
        pts = []
        faces.each do |f|
          next unless f && f.valid?
          f.outer_loop.vertices.each { |v| pts << v.position }
        rescue StandardError
          nil
        end
        raise 'No wrap vertices for UV' if pts.empty?

        xs = pts.map { |p| p.x.to_f }
        ys = pts.map { |p| p.y.to_f }
        zs = pts.map { |p| p.z.to_f }
        dx = xs.max - xs.min
        dy = ys.max - ys.min
        dz = zs.max - zs.min
        # Horizontal U along the longer plan axis (wrap width).
        if dx >= dy
          {
            u_axis: 0, u0: xs.min, u1: xs.max,
            v0: zs.min, v1: zs.max,
            width: [dx, 1.0.mm].max, height: [dz, 1.0.mm].max
          }
        else
          {
            u_axis: 1, u0: ys.min, u1: ys.max,
            v0: zs.min, v1: zs.max,
            width: [dy, 1.0.mm].max, height: [dz, 1.0.mm].max
          }
        end
      end

      def wrap_u_of(point, frame)
        span = frame[:u1] - frame[:u0]
        return 0.0 if span.abs < 1e-12
        raw = frame[:u_axis] == 0 ? point.x.to_f : point.y.to_f
        frac = (raw - frame[:u0]) / span
        frac = 0.0 if frac < 0.0
        frac = 1.0 if frac > 1.0
        frac
      end

      def wrap_v_of(point, frame)
        span = frame[:v1] - frame[:v0]
        return 0.0 if span.abs < 1e-12
        frac = (point.z.to_f - frame[:v0]) / span
        frac = 0.0 if frac < 0.0
        frac = 1.0 if frac > 1.0
        frac
      end

      def wrap_planar_uv_pair(verts, frame, tex_w, tex_h)
        return nil if verts.nil? || verts.size < 2
        a = verts.min_by { |p| wrap_u_of(p, frame) }
        b = verts.max_by { |p| wrap_u_of(p, frame) }
        return nil if a.nil? || b.nil? || a == b
        ua = Geom::Point3d.new(wrap_u_of(a, frame) * tex_w, wrap_v_of(a, frame) * tex_h, 0)
        ub = Geom::Point3d.new(wrap_u_of(b, frame) * tex_w, wrap_v_of(b, frame) * tex_h, 0)
        return nil if (ua.x - ub.x).abs < 1e-9 && (ua.y - ub.y).abs < 1e-9
        [a, ua, b, ub]
      end

      def wrap_planar_uv_mapping(verts, frame, tex_w, tex_h)
        return nil if verts.nil? || verts.size < 3
        a = verts.min_by { |p| wrap_u_of(p, frame) }
        b = verts.max_by { |p| wrap_u_of(p, frame) }
        c = verts.max_by { |p| wrap_v_of(p, frame) }
        trio = [a, b, c].compact.uniq
        return wrap_planar_uv_pair(verts, frame, tex_w, tex_h) if trio.size < 3

        mapping = []
        trio.each do |p|
          mapping << p
          mapping << Geom::Point3d.new(wrap_u_of(p, frame) * tex_w, wrap_v_of(p, frame) * tex_h, 0)
        end
        mapping
      end

      # Soft+smooth only (no hide) — v0.1.65 hide blanked the textured front.
      def soften_smooth_graphic_front_edges!(faces)
        return if faces.nil? || faces.empty?
        seen = {}
        faces.each do |face|
          next unless face && face.valid?
          face.edges.each do |e|
            next unless e && e.valid?
            next if seen[e.entityID]
            seen[e.entityID] = true
            next if e.faces.size < 2
            begin
              e.soft = true
              e.smooth = true
              # Do not hide edges — that blanked textured fronts in v0.1.65.
            rescue StandardError
              nil
            end
          end
        end
      rescue StandardError
        nil
      end

      def apron_developed_size_mm(faces, source)
        frame = apron_uv_frame(faces)
        w_mm = frame[:arc_len].to_f / 1.mm
        h_mm = frame[:height].to_f / 1.mm
        w_mm = Constants::GRAPHIC_BAY_MM if w_mm < 10.0
        h_mm = 300.0 if h_mm < 10.0
        begin
          rep = source.is_a?(Hash) ? source[:rep] : nil
          if rep && rep.width.to_i > 0 && rep.height.to_i > 0
            # Keep image aspect: height from width × aspect (cover apron width).
            aspect = rep.height.to_f / rep.width.to_f
            h_from_aspect = w_mm * aspect
            # Prefer fitting the taller of developed apron height vs aspect height.
            h_mm = [h_mm, h_from_aspect].max
          end
        rescue StandardError
          nil
        end
        [w_mm, h_mm]
      end

      # Continuous unwrap in lip-local space: U = angle in horizontal plane, V = up.
      # Opaque both sides (posts/beams must not show through). Soft+hide edges so
      # the graphic wrap front reads as one clean surface (no tessellation lines).
      def paint_apron_continuous!(faces, material)
        return 0 if faces.nil? || faces.empty?
        frame = apron_uv_frame(faces)
        tex_w, tex_h = texture_dims(material, frame[:arc_len], frame[:height])
        painted = 0
        faces.each do |face|
          begin
            next unless face.valid?
            verts = face.outer_loop.vertices.map(&:position)
            next if verts.size < 3
            face.material = material
            begin
              # Opaque reverse — nil back_material lets posts show through.
              face.back_material = material
            rescue StandardError
              nil
            end
            mapping = apron_uv_mapping(verts, frame, tex_w, tex_h)
            if mapping
              begin
                face.position_material(material, mapping, true)
              rescue StandardError
                nil
              end
            end
            painted += 1
          rescue StandardError
            nil
          end
        end
        soften_hide_graphic_front_edges!(faces)
        painted
      end

      # Soft + smooth edges on painted graphic faces (no hide — hide blanked
      # textured fronts in v0.1.65). Kept name for older call sites.
      def soften_hide_graphic_front_edges!(faces)
        soften_smooth_graphic_front_edges!(faces)
      end

      def apron_uv_frame(faces)
        pts = []
        faces.each do |f|
          f.outer_loop.vertices.each { |v| pts << v.position }
        rescue StandardError
          nil
        end
        raise 'No apron vertices for UV' if pts.empty?

        up = Tables.detect_lip_up_axis(faces)
        # Horizontal plane axes for angle unwrap.
        h0, h1 = case up
                 when 0 then [1, 2] # YZ plane → use y,z
                 when 1 then [0, 2] # XZ
                 else [0, 1]       # XY (up = Z)
                 end

        c0 = pts.map { |p| point_comp(p, h0) }.inject(0.0, :+) / pts.size
        c1 = pts.map { |p| point_comp(p, h1) }.inject(0.0, :+) / pts.size
        ups = pts.map { |p| point_comp(p, up) }
        u0 = ups.min
        u1 = ups.max
        height = [(u1 - u0).abs, 1.0.mm].max

        angles = pts.map { |p| Math.atan2(point_comp(p, h1) - c1, point_comp(p, h0) - c0) }
        a_sorted = angles.sort
        a0 = a_sorted.first
        a1 = a_sorted.last
        span = a1 - a0
        if span < 1e-6
          span = 2.0 * Math::PI
          a0 = -Math::PI
          a1 = Math::PI
        end
        radii = pts.map do |p|
          Math.hypot(point_comp(p, h0) - c0, point_comp(p, h1) - c1)
        end
        r = radii.inject(0.0, :+) / radii.size
        r = 100.mm if r < 1.mm
        arc_len = r * span.abs

        {
          up: up, h0: h0, h1: h1,
          c0: c0, c1: c1, v0: u0, v1: u1,
          a0: a0, a1: a1, span: span,
          radius: r, arc_len: arc_len, height: height
        }
      end

      def point_comp(p, axis)
        case axis
        when 0 then p.x.to_f
        when 1 then p.y.to_f
        else p.z.to_f
        end
      end

      def apron_uv_mapping(verts, frame, tex_w, tex_h)
        scored = verts.map do |p|
          ang = Math.atan2(
            point_comp(p, frame[:h1]) - frame[:c1],
            point_comp(p, frame[:h0]) - frame[:c0]
          )
          upv = point_comp(p, frame[:up])
          [p, ang, upv]
        end
        return nil if scored.size < 2
        a = scored.min_by { |(_, ang, _)| ang }
        b = scored.max_by { |(_, ang, _)| ang }
        c = scored.max_by { |(_, _, z)| (z - frame[:v0]).abs }
        trio = [a, b, c].uniq { |t| t[0] }
        return nil if trio.size < 2

        mapping = []
        trio.first(3).each do |p, ang, upv|
          u = apron_u(ang, frame, tex_w)
          v = apron_v(upv, frame, tex_h)
          mapping << p
          mapping << Geom::Point3d.new(u, v, 0)
        end
        mapping.size >= 4 ? mapping : nil
      end

      def apron_u(ang, frame, tex_w)
        span = frame[:span]
        return 0.0 if span.abs < 1e-9
        frac = (ang - frame[:a0]) / span
        frac = 0.0 if frac < 0.0
        frac = 1.0 if frac > 1.0
        frac * tex_w
      end

      def apron_v(up_val, frame, tex_h)
        h = frame[:height]
        return 0.0 if h < 1e-9
        frac = (up_val.to_f - frame[:v0]) / h
        frac = 0.0 if frac < 0.0
        frac = 1.0 if frac > 1.0
        frac * tex_h
      end

      def map_table_lip_faces!(lip, material)
        return 0 unless lip && lip.valid?
        faces = []
        Tables.gather_faces_deep!(lip, faces, 0)
        up = Tables.detect_lip_up_axis(faces)
        apron = Tables.filter_lip_apron_faces(faces, up)
        apron = faces.select { |f| f.valid? && Tables.normal_up_component(f.normal, up).abs < 0.92 } if apron.empty?
        paint_apron_continuous!(apron, material)
      end

      def map_table_apron_faces_from_definition!(defn, material)
        paint_apron_continuous!(Tables.select_keyboard_apron_faces(defn), material)
      end

      def ensure_table_material!(model, table_key, image_path)
        # Compatibility wrapper — size is corrected in ensure_table_apron_material!.
        name = "ISOframe Table Artwork #{table_key}"
        mat = model.materials[name] || model.materials.add(name)
        source = load_source_rep!(image_path)
        load_path = source.is_a?(Hash) ? source[:path] : nil
        load_path = safe_image_load_path(normalize_image_path(image_path)) if load_path.nil? || !File.file?(load_path.to_s)
        begin
          mat.texture = load_path
        rescue StandardError
          mat.texture = image_path
        end
        raise 'SketchUp could not load under-table texture' if mat.texture.nil?
        set_texture_size!(mat, Constants::GRAPHIC_BAY_MM, 400.0)
        mat
      end

      def map_table_graphic_group!(group, material)
        faces = collect_faces_deep(group, 0)
        front = select_front_panel_faces(faces)
        # Under-table apron may face outward with more Z tilt — also accept
        # large faces that are not floor/ceiling.
        if front.empty?
          front = faces.select do |f|
            next false unless f.valid?
            n = f.normal
            next false if n.z.abs >= 0.85
            face_area_mm2(f) >= MIN_FRONT_AREA_MM2
          end
        end
        return 0 if front.empty?

        bay_w = Constants::GRAPHIC_BAY_MM.mm
        tex_w, tex_h = texture_dims(material, bay_w, 1000.mm)
        painted = 0
        front.each do |face|
          begin
            face.material = material
            face.back_material = material
            # Planar fit: left→right along local X, V up Z.
            verts = face.outer_loop.vertices.map(&:position)
            if verts.size >= 2
              a = verts.min_by(&:x)
              b = verts.max_by(&:x)
              uv_a = Geom::Point3d.new(0, a.z, 0)
              uv_b = Geom::Point3d.new(tex_w, b.z, 0)
              begin
                face.position_material(material, [a, uv_a, b, uv_b], true)
              rescue StandardError
                nil
              end
            end
            painted += 1
          rescue StandardError
            nil
          end
        end
        painted
      end

      def collect_faces_deep(entity, depth)
        return [] if entity.nil? || depth > 8
        ents = if entity.is_a?(Sketchup::Group)
                 entity.entities
               elsif entity.is_a?(Sketchup::ComponentInstance)
                 entity.definition.entities
               elsif entity.is_a?(Sketchup::Entities)
                 entity
               elsif entity.respond_to?(:entities)
                 entity.entities
               end
        return [] unless ents
        faces = ents.grep(Sketchup::Face).select(&:valid?)
        ents.each do |e|
          next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
          faces.concat(collect_faces_deep(e, depth + 1))
        end
        faces
      end

      def selected_wave_module(model)
        model.selection.grep(Sketchup::ComponentInstance).find do |inst|
          type = Attributes.get(inst, Constants::KEY_TYPE)
          type == Constants::TYPE_STARTER || type == Constants::TYPE_EXTENSION
        end
      end

      # Texture / UV height = HEIGHTS_MM graphic panel height (z_top − z_bot).
      def height_mm_for(inst)
        key = Attributes.get(inst, Constants::KEY_HEIGHT, Constants::DEFAULT_HEIGHT).to_s
        graphic_mm = Constants::HEIGHTS_MM[key] || Constants::HEIGHTS_MM[Constants::DEFAULT_HEIGHT]
        Geometry.graphic_panel_height_mm(graphic_mm)
      end

      def material_name(wall_id, bay_index = nil)
        if bay_index.nil?
          "ISOframe Artwork #{wall_id}"
        else
          "ISOframe Artwork #{wall_id} bay#{bay_index}"
        end
      end

      def normalize_image_path(path)
        return nil if path.nil?
        s = path.to_s.strip
        return nil if s.empty?
        # UI.openpanel / macOS may wrap paths in quotes.
        s = s[1..-2] if (s.start_with?('"') && s.end_with?('"')) ||
                        (s.start_with?("'") && s.end_with?("'"))
        s = s.tr('\\', '/')
        begin
          s = File.expand_path(s)
        rescue StandardError
          # keep s
        end
        return s if File.file?(s)
        if s.include?(':') && !s.start_with?('/')
          parts = s.split(':')
          parts.shift if parts.first =~ /Macintosh HD|macOS|ssd/i
          alt = '/' + parts.join('/')
          return alt if File.file?(alt)
        end
        s
      end

      # SketchUp ImageRep / texture load can fail on spaces in folder names and
      # on `.jpeg` (vs `.jpg`). Copy to a temp path without spaces when needed.
      def path_needs_safe_copy?(path)
        return false if path.nil? || path.to_s.empty?
        s = path.to_s
        return true if s.include?(' ')
        return true if s.match?(/[\[\]\(\)\{\}']/)
        ext = File.extname(s).downcase
        ext == '.jpeg'
      end

      def safe_image_load_path(path)
        return path unless path && File.file?(path)
        return path unless path_needs_safe_copy?(path)
        copy_image_to_safe_temp(path)
      end

      def copy_image_to_safe_temp(path)
        require 'fileutils'
        require 'tmpdir'
        ext = File.extname(path.to_s).downcase
        ext = '.jpg' if ext == '.jpeg' || ext.empty?
        unless ['.jpg', '.png', '.tif', '.tiff', '.bmp'].include?(ext)
          ext = '.jpg'
        end
        dir = File.join(Dir.tmpdir, 'isoframe_artwork')
        FileUtils.mkdir_p(dir)
        dest = File.join(
          dir,
          "art_#{Process.pid}_#{Time.now.to_i}_#{rand(100_000)}#{ext}"
        )
        FileUtils.cp(path, dest)
        dest
      rescue StandardError
        path
      end

      def try_image_rep_load(rep, path)
        return false unless rep && path && File.file?(path)
        ok = false
        begin
          result = rep.load_file(path)
          ok = (result != false)
        rescue StandardError
          ok = false
        end
        ok && rep.width.to_i > 0
      rescue StandardError
        false
      end

      def load_source_rep!(image_path)
        path = normalize_image_path(image_path)
        raise "Image file not found: #{image_path}" unless path && File.file?(path)
        load_path = safe_image_load_path(path)
        unless defined?(Sketchup::ImageRep)
          return { path: load_path, rep: nil, source_path: path }
        end
        rep = Sketchup::ImageRep.new
        ok = try_image_rep_load(rep, load_path)
        if !ok && load_path != path
          ok = try_image_rep_load(rep, path)
          load_path = path if ok
        end
        unless ok
          # Force a .jpg temp copy even if the original path looked safe.
          forced = copy_image_to_safe_temp(path)
          if forced && forced != load_path && File.file?(forced)
            ok = try_image_rep_load(rep, forced)
            load_path = forced if ok
          end
        end
        raise "SketchUp could not load image:\n#{path}" unless ok && rep.width.to_i > 0
        { path: load_path, rep: rep, source_path: path }
      end

      # One material per bay whose texture pixels are ONLY that bay's horizontal
      # slice of the source photo. Default SketchUp fit then shows the slice —
      # no dependence on position_material succeeding.
      def ensure_bay_material!(model, wall_id, bay_index, bay_count, source, image_path, height_mm)
        name = material_name(wall_id, bay_index)
        mat = model.materials[name]
        mat ||= model.materials.add(name)
        bay_w_mm = Constants::GRAPHIC_BAY_MM
        loaded = false
        rep = source.is_a?(Hash) ? source[:rep] : nil
        if rep && defined?(Sketchup::ImageRep)
          cropped = crop_rep_for_bay(rep, bay_index, bay_count)
          if cropped
            begin
              mat.texture = cropped
              loaded = !mat.texture.nil?
            rescue StandardError
              loaded = false
            end
          end
        end
        unless loaded
          # Fallback: full image on bay material + UV window (may still tile if UV fails).
          path = source.is_a?(Hash) ? source[:path] : nil
          path = safe_image_load_path(normalize_image_path(image_path)) if path.nil? || !File.file?(path.to_s)
          if path && File.file?(path)
            begin
              mat.texture = path
              loaded = !mat.texture.nil?
            rescue StandardError
              loaded = false
            end
          end
        end
        raise "SketchUp could not load texture for bay #{bay_index}" unless loaded
        set_texture_size!(mat, bay_w_mm, height_mm)
        mat
      end

      def crop_rep_for_bay(src_rep, bay_index, bay_count)
        return nil unless src_rep
        w = src_rep.width.to_i
        h = src_rep.height.to_i
        return nil if w < 1 || h < 1
        x0, x1 = bay_pixel_window(bay_index, bay_count, w)
        crop_w = x1 - x0
        return nil if crop_w < 1
        return src_rep if crop_w == w && x0 == 0

        bpp = src_rep.bits_per_pixel.to_i
        bpp = 24 if bpp < 8
        bytes_pp = bpp / 8
        src_data = src_rep.data
        return nil if src_data.nil? || src_data.empty?
        src_stride = src_data.bytesize / h
        return nil if src_stride < w * bytes_pp

        dst_row_bytes = crop_w * bytes_pp
        dst_padding = (4 - (dst_row_bytes % 4)) % 4
        out = String.new(encoding: Encoding::BINARY)
        h.times do |row|
          src_off = row * src_stride + x0 * bytes_pp
          slice = src_data.byteslice(src_off, dst_row_bytes)
          return nil if slice.nil? || slice.bytesize != dst_row_bytes
          out << slice
          out << ("\x00" * dst_padding) if dst_padding > 0
        end
        dst = Sketchup::ImageRep.new
        ok = dst.set_data(crop_w, h, bpp, dst_padding, out)
        return nil unless ok
        dst
      rescue StandardError
        nil
      end

      def set_texture_size!(mat, width_mm, height_mm)
        return unless mat && mat.texture
        w = width_mm.to_f.mm
        h = height_mm.to_f.mm
        mat.texture.size = [w, h]
      rescue StandardError
        begin
          mat.texture.size = [w, h] if mat && mat.texture
        rescue StandardError
          nil
        end
      end

      def map_instance!(inst, material, bay_index, bay_count, height_mm)
        return 0 unless inst && inst.valid? && material
        type = Attributes.get(inst, Constants::KEY_TYPE)
        height_key = Attributes.get(inst, Constants::KEY_HEIGHT, Constants::DEFAULT_HEIGHT)
        if defined?(Geometry.force_unique_definition!)
          Geometry.force_unique_definition!(inst, type, height_key)
        elsif inst.definition.instances.size > 1
          inst.make_unique
        end
        defn = inst.definition
        groups = graphic_groups(defn)
        if groups.empty?
          raise "No #{Geometry::GROUP_GRAPHIC} group in #{defn.name}"
        end
        angle = Attributes.get(inst, Constants::KEY_FLEX, 0.0).to_f
        count = 0
        groups.each do |group|
          count += map_graphic_group!(group, material, bay_index, bay_count, height_mm, angle)
        end
        count
      end

      def graphic_groups(defn)
        return [] unless defn && defn.valid?
        defn.entities.grep(Sketchup::Group).select do |g|
          g.valid? && g.name.to_s == Geometry::GROUP_GRAPHIC
        end
      end

      # Visible wall wallpaper: proven v0.1.58/61 UV on FRONT faces (both sides
      # of those faces get the wallpaper Material — required on this soft 3mm
      # panel; Color/nil on back_material made Apply Artwork a no-op in v59/v63).
      # Then force rear *slab* faces to a named plain Material (framework side).
      def map_graphic_group!(group, material, bay_index, bay_count, height_mm, flex_angle_deg = 0.0)
        faces = group.entities.grep(Sketchup::Face).select { |f| f.valid? }
        path = bay_front_path(flex_angle_deg)
        # Large vertical faces (same as v0.1.58) — includes front + rear slabs.
        vertical = select_vertical_panel_faces(faces)
        return 0 if vertical.empty?

        front, rear = partition_front_rear_faces(vertical, path)
        if front.empty?
          front, rear = recover_front_faces_from_vertical(vertical, path)
        end
        # Last resort (odd transforms): paint verticals, then strip rear after.
        if front.empty?
          front = vertical
          rear = []
        end

        bay_w = Constants::GRAPHIC_BAY_MM.mm
        tex_w, tex_h = texture_dims(material, bay_w, height_mm.to_f.mm)
        u0 = 0.0
        u1 = tex_w
        h = tex_h
        cum = path_cumulative_lengths(path)
        total = cum.empty? ? 0.0 : cum.last
        total = bay_w if total < 1e-9

        painted = 0
        front.each do |face|
          painted += 1 if paint_front_face!(face, material, u0, u1, h, path, cum, total)
        end

        # Re-classify so true rear slabs never keep wallpaper (even if fallback
        # painted all verticals). Plain Material — not nil (light-blue).
        model = wall_group_model(group)
        front_keep, rear_force = partition_front_rear_faces(vertical, path)
        if front_keep.empty?
          restore_plain_wall_faces!(rear, model)
          restore_plain_wall_faces!(faces - front - rear, model)
          soften_hide_graphic_front_edges!(front)
        else
          restore_plain_wall_faces!(rear_force, model)
          restore_plain_wall_faces!(faces - front_keep - rear_force, model)
          soften_hide_graphic_front_edges!(front_keep)
        end
        # Also soft longitudinal seams inside the GraphicHint group (posts must
        # not read through panel ribs).
        begin
          Geometry.soften_longitudinal_seams!(group.entities) if group.valid?
        rescue StandardError
          nil
        end

        painted
      end

      def texture_dims(material, fallback_w, fallback_h)
        w = fallback_w.to_f
        h = fallback_h.to_f
        if material && material.texture
          begin
            sz = material.texture.size
            if sz.is_a?(Array) && sz.size >= 2
              w = sz[0].to_f if sz[0].to_f > 1e-9
              h = sz[1].to_f if sz[1].to_f > 1e-9
            end
          rescue StandardError
            # keep fallback
          end
        end
        [w, h]
      end

      def bay_front_path(flex_angle_deg)
        ang = flex_angle_deg.to_f
        hinge = Geometry.hinge_center_local
        free = Geometry.end_post_center_local(ang)
        Geometry.face_path(hinge, free, ang, Constants::HALF_POST_MM.mm)
      end

      def path_cumulative_lengths(path)
        return [] if path.nil? || path.size < 2
        cum = [0.0]
        (1...path.size).each do |i|
          a = path[i - 1]
          b = path[i]
          cum << cum.last + Math.hypot(b.x - a.x, b.y - a.y)
        end
        cum
      end

      def path_s_at(point, path, cum)
        return 0.0 if path.nil? || path.size < 2 || cum.empty?
        px = point.x
        py = point.y
        best_d2 = nil
        best_s = 0.0
        (0...path.size - 1).each do |i|
          ax = path[i].x
          ay = path[i].y
          bx = path[i + 1].x
          by = path[i + 1].y
          dx = bx - ax
          dy = by - ay
          len2 = dx * dx + dy * dy
          t = 0.0
          if len2 > 1e-18
            t = ((px - ax) * dx + (py - ay) * dy) / len2
            t = 0.0 if t < 0.0
            t = 1.0 if t > 1.0
          end
          qx = ax + t * dx
          qy = ay + t * dy
          d2 = (px - qx) * (px - qx) + (py - qy) * (py - qy)
          if best_d2.nil? || d2 < best_d2
            best_d2 = d2
            seg_len = Math.sqrt(len2)
            best_s = cum[i] + t * seg_len
          end
        end
        best_s
      end

      def uv_for_point(point, u0, u1, h, path, cum, total)
        s = path_s_at(point, path, cum)
        frac = total.abs < 1e-12 ? 0.0 : (s / total)
        frac = 0.0 if frac < 0.0
        frac = 1.0 if frac > 1.0
        u = u0 + frac * (u1 - u0)
        v = point.z.to_f
        v = 0.0 if v < 0.0
        v = h if v > h
        Geom::Point3d.new(u, v, 0)
      end

      # v0.1.58-compatible: all large vertical panel faces (front + rear).
      def select_vertical_panel_faces(faces)
        faces.select do |f|
          next false unless f.valid?
          n = f.normal
          next false if n.z.abs >= 0.40
          face_area_mm2(f) >= MIN_FRONT_AREA_MM2
        end
      end

      # Front = outward toward floorspace; rear = opposite (flex-link side).
      def partition_front_rear_faces(faces, path = nil)
        path ||= bay_front_path(0.0)
        front = []
        rear = []
        faces.each do |f|
          next unless f.valid?
          outward = front_outward_normal_at(f.bounds.center, path)
          if outward.nil?
            front << f
            next
          end
          dot = f.normal.dot(outward)
          if dot > 0.15
            front << f
          elsif dot < -0.15
            rear << f
          else
            # Side/edge strips — leave unpainted.
            rear << f
          end
        end
        [front, rear]
      end

      # Kept for table helpers / older call sites.
      def select_front_panel_faces(faces, path = nil)
        vertical = select_vertical_panel_faces(faces)
        return vertical if path.nil?
        front, _rear = partition_front_rear_faces(vertical, path)
        front.empty? ? vertical : front
      end

      PLAIN_WALL_MATERIAL_NAME = 'ISOframe Graphic Plain'

      def plain_wall_color
        rgb = Geometry::GRAPHIC_PLAIN_RGB
        Sketchup::Color.new(rgb[0], rgb[1], rgb[2])
      rescue StandardError
        Sketchup::Color.new(230, 235, 245)
      end

      def wall_group_model(group)
        return group.model if group.respond_to?(:model) && group.model
        parent = group.entities.parent if group.respond_to?(:entities)
        return parent if parent.is_a?(Sketchup::Model)
        return parent.model if parent.respond_to?(:model)
        nil
      rescue StandardError
        nil
      end

      # Named opaque Material (not raw Color, not nil) for rear slab / scraps.
      def ensure_plain_wall_material!(model)
        color = plain_wall_color
        return color unless model && model.respond_to?(:materials)
        mat = model.materials[PLAIN_WALL_MATERIAL_NAME]
        mat = model.materials.add(PLAIN_WALL_MATERIAL_NAME) if mat.nil?
        begin
          mat.color = color
          mat.texture = nil if mat.respond_to?(:texture=)
        rescue StandardError
          nil
        end
        mat
      rescue StandardError
        plain_wall_color
      end

      # Prefer least-inward vertical faces when partition found no outward front.
      def recover_front_faces_from_vertical(vertical, path)
        scored = vertical.map do |f|
          next unless f.valid?
          out = front_outward_normal_at(f.bounds.center, path)
          dot = out.nil? ? 0.0 : f.normal.dot(out)
          [dot, f]
        end.compact
        return [[], vertical] if scored.empty?

        max_dot = scored.map(&:first).max
        # Refuse strongly inward faces — those are the framework/flex-link side.
        front = scored.select { |d, _| d >= max_dot - 0.05 && d > -0.5 }.map(&:last)
        rear = vertical - front
        [front, rear]
      end

      def restore_plain_wall_faces!(faces, model = nil)
        return if faces.nil? || faces.empty?
        plain = ensure_plain_wall_material!(model)
        faces.each do |f|
          next unless f && f.valid?
          begin
            f.material = plain
            f.back_material = plain
          rescue StandardError
            nil
          end
        end
      end

      # Kept name for older call sites / tests — restores plain tint (not nil).
      def clear_wall_face_materials!(faces)
        restore_plain_wall_faces!(faces, nil)
      end

      def front_outward_normal_at(point, path)
        return Geom::Vector3d.new(0, 1, 0) if path.nil? || path.size < 2
        # Nearest path segment → left normal (same as Geometry panel front).
        best_i = 0
        best_d2 = nil
        (0...path.size - 1).each do |i|
          a = path[i]
          b = path[i + 1]
          dx = b.x - a.x
          dy = b.y - a.y
          len2 = dx * dx + dy * dy
          next if len2 < 1e-18
          t = ((point.x - a.x) * dx + (point.y - a.y) * dy) / len2
          t = 0.0 if t < 0.0
          t = 1.0 if t > 1.0
          qx = a.x + t * dx
          qy = a.y + t * dy
          d2 = (point.x - qx)**2 + (point.y - qy)**2
          if best_d2.nil? || d2 < best_d2
            best_d2 = d2
            best_i = i
          end
        end
        a = path[best_i]
        b = path[[best_i + 1, path.size - 1].min]
        tx = b.x - a.x
        ty = b.y - a.y
        len = Math.hypot(tx, ty)
        return Geom::Vector3d.new(0, 1, 0) if len < 1e-9
        # Left normal of tangent (tx,ty) = (-ty, tx) — matches Geometry.left_normal.
        nx = -ty / len
        ny = tx / len
        Geom::Vector3d.new(nx, ny, 0)
      rescue StandardError
        Geom::Vector3d.new(0, 1, 0)
      end

      def restore_non_front_wall_faces!(all_faces, front_faces, model = nil)
        front_ids = {}
        front_faces.each { |f| front_ids[f.entityID] = true if f.valid? }
        extras = all_faces.select { |f| f.valid? && !front_ids[f.entityID] }
        restore_plain_wall_faces!(extras, model)
      end

      # Alias — older name cleared to nil (light-blue); now restores plain tint.
      def clear_non_front_wall_materials!(all_faces, front_faces)
        restore_non_front_wall_faces!(all_faces, front_faces, nil)
      end

      def face_area_mm2(face)
        face.area.to_f * 25.4 * 25.4
      rescue StandardError
        0.0
      end

      def paint_front_face!(face, material, u0, u1, h, path, cum, total)
        # v0.1.58/61: BOTH sides of the FRONT face get the wallpaper Material so
        # the soft 3mm panel displays the texture. Rear *slab* faces are forced
        # plain afterward — do NOT put Color/nil on back_material here (v59/v63
        # no-op / light-blue regressions).
        face.material = material
        face.back_material = material
        verts = face.outer_loop.vertices.map(&:position)
        return material_only_ok?(face, material) if verts.size < 3

        try_position_uv!(face, material, verts, u0, u1, h, path, cum, total)
        material_only_ok?(face, material)
      rescue StandardError
        begin
          face.material = material
          face.back_material = material
        rescue StandardError
          nil
        end
        material_only_ok?(face, material)
      end

      def try_position_uv!(face, material, verts, u0, u1, h, path, cum, total)
        softened = harden_face_edges(face)
        begin
          pair = uv_candidate_pair(verts, path, cum)
          if pair
            a, b = pair
            uv_a = uv_for_point(a, u0, u1, h, path, cum, total)
            uv_b = uv_for_point(b, u0, u1, h, path, cum, total)
            if (uv_a.x - uv_b.x).abs >= 1e-9 || (uv_a.y - uv_b.y).abs >= 1e-9
              begin
                ok = face.position_material(material, [a, uv_a, b, uv_b], true)
                return true if ok != false
              rescue StandardError
                # fall through
              end
            end
          end

          triplets = uv_candidate_triplets(verts, path, cum)
          triplets.each do |a, b, c|
            uv_a = uv_for_point(a, u0, u1, h, path, cum, total)
            uv_b = uv_for_point(b, u0, u1, h, path, cum, total)
            uv_c = uv_for_point(c, u0, u1, h, path, cum, total)
            next unless triangle_area3(a, b, c) >= MIN_TRI_AREA_IN2
            next unless triangle_area_uv(uv_a, uv_b, uv_c) >= MIN_UV_AREA

            mapping = [a, uv_a, b, uv_b, c, uv_c]
            begin
              ok = face.position_material(material, mapping, true)
              return true if ok != false
            rescue StandardError
              # try next
            end
          end
          false
        ensure
          restore_face_edges(softened)
        end
      end

      def harden_face_edges(face)
        return [] unless face && face.valid?
        face.edges.map do |e|
          next unless e.valid?
          state = [e, e.soft?, e.smooth?]
          e.soft = false
          e.smooth = false
          state
        end.compact
      rescue StandardError
        []
      end

      def restore_face_edges(states)
        return if states.nil? || states.empty?
        states.each do |e, soft, smooth|
          next unless e && e.valid?
          e.soft = soft
          e.smooth = smooth
        end
      rescue StandardError
        nil
      end

      def uv_candidate_pair(verts, path, cum)
        z_min = verts.map(&:z).min
        z_tol = [(verts.map(&:z).max - z_min) * 0.15, 1.0.mm].max
        bot = verts.select { |p| p.z <= z_min + z_tol }
        bot = verts.sort_by(&:z).first(2) if bot.size < 2
        bot_sorted = bot.sort_by { |p| path_s_at(p, path, cum) }
        bl = bot_sorted.first
        br = bot_sorted.last
        return nil unless bl && br
        return nil if bl == br
        [bl, br]
      end

      def uv_candidate_triplets(verts, path, cum)
        list = []
        z_min = verts.map(&:z).min
        z_max = verts.map(&:z).max
        z_tol = [(z_max - z_min) * 0.15, 1.0.mm].max
        bot = verts.select { |p| p.z <= z_min + z_tol }
        top = verts.select { |p| p.z >= z_max - z_tol }
        bot = verts.sort_by(&:z).first(2) if bot.size < 2
        top = verts.sort_by { |p| -p.z }.first(2) if top.size < 1

        bot_sorted = bot.sort_by { |p| path_s_at(p, path, cum) }
        bl = bot_sorted.first
        br = bot_sorted.last
        tl = top.min_by { |p| path_s_at(p, path, cum) }
        tr = top.max_by { |p| path_s_at(p, path, cum) }
        list << [bl, br, tl] if bl && br && tl
        list << [bl, br, tr] if bl && br && tr
        list << [bl, tr, tl] if bl && tr && tl

        n = verts.size
        (0...n).each do |i|
          ((i + 1)...n).each do |j|
            ((j + 1)...n).each do |k|
              list << [verts[i], verts[j], verts[k]]
            end
          end
        end
        list.uniq
      end

      def triangle_area3(a, b, c)
        ux = b.x - a.x
        uy = b.y - a.y
        uz = b.z - a.z
        vx = c.x - a.x
        vy = c.y - a.y
        vz = c.z - a.z
        cx = uy * vz - uz * vy
        cy = uz * vx - ux * vz
        cz = ux * vy - uy * vx
        0.5 * Math.sqrt(cx * cx + cy * cy + cz * cz)
      rescue StandardError
        0.0
      end

      def triangle_area_uv(ua, ub, uc)
        triangle_area3(ua, ub, uc)
      end

      def material_only_ok?(face, material)
        face.material == material
      rescue StandardError
        false
      end
    end
  end
end
