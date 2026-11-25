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
            raise 'No under-table graphic faces found to paint.'
          end
          model.commit_operation
          msg = "Table artwork applied (#{painted} face#{painted == 1 ? '' : 's'}). " \
                'Wall wallpaper is unchanged.'
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
        defn = table_inst.definition
        # Make definition unique so tagging/ensure does not mutate other instances.
        begin
          if defn.respond_to?(:make_unique) && defn.count_instances.to_i > 1
            table_inst.make_unique if table_inst.respond_to?(:make_unique)
            defn = table_inst.definition
          end
        rescue StandardError
          nil
        end

        # v0.1.57: purge flat synthetic panels; paint real curved lip/apron only.
        Tables.purge_synthetic_table_graphic_panels!(defn)
        target = Tables.ensure_table_graphic_group!(defn, 'TableGraphicHint')
        lip = Tables.find_keyboard_lip_entity(defn.entities, 0)
        lip = target if lip.nil? && target && target.valid? && !Tables.synthetic_table_graphic?(target)

        raise 'No under-table graphic group in keyboard table' if lip.nil? || !lip.valid?
        raise 'Refusing to paint synthetic flat panel' if Tables.synthetic_table_graphic?(lip)

        mid = Attributes.get(table_inst, Constants::KEY_TABLE_HOST, 'table').to_s
        mat = ensure_table_material!(table_inst.model, mid, image_path)
        painted = map_table_lip_faces!(lip, mat)
        # If lip facets were filtered too aggressively, paint all non-floor faces.
        painted = map_table_graphic_group!(lip, mat) if painted <= 0
        raise 'No under-table graphic faces found to paint.' if painted <= 0
        painted
      end

      # Paint curved apron faces inside the SKP keyboard lip (small facets OK).
      def map_table_lip_faces!(lip, material)
        faces = collect_faces_deep(lip, 0)
        apron = faces.select do |f|
          next false unless f.valid?
          n = f.normal
          # Skip floor/ceiling; keep curved vertical-ish facets.
          next false if n.z.abs >= 0.92
          face_area_mm2(f) >= 20.0
        end
        return 0 if apron.empty?

        bay_w = Constants::GRAPHIC_BAY_MM.mm
        tex_w, tex_h = texture_dims(material, bay_w, 1000.mm)
        painted = 0
        apron.each do |face|
          begin
            face.material = material
            face.back_material = material
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

      def ensure_table_material!(model, table_key, image_path)
        name = "ISOframe Table Artwork #{table_key}"
        mat = model.materials[name] || model.materials.add(name)
        source = load_source_rep!(image_path)
        # Full image on the under-table panel (not wall bay crop / wallpaper).
        load_path = source.is_a?(Hash) ? source[:path] : nil
        load_path = safe_image_load_path(normalize_image_path(image_path)) if load_path.nil? || !File.file?(load_path.to_s)
        begin
          mat.texture = load_path
        rescue StandardError
          mat.texture = image_path
        end
        raise 'SketchUp could not load under-table texture' if mat.texture.nil?

        bay_w_mm = Constants::GRAPHIC_BAY_MM
        height_mm = 1000.0
        begin
          rep = source.is_a?(Hash) ? source[:rep] : nil
          if rep && rep.width.to_i > 0 && rep.height.to_i > 0
            height_mm = bay_w_mm * (rep.height.to_f / rep.width.to_f)
          end
        rescue StandardError
          height_mm = 1000.0
        end
        set_texture_size!(mat, bay_w_mm, height_mm)
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

      # Paint front facets. Material texture is already the bay crop, so U runs
      # 0→bay_w within this bay (slice of the wall). Path frac still drives U
      # along the bay for curved panels when position_material works.
      def map_graphic_group!(group, material, bay_index, bay_count, height_mm, flex_angle_deg = 0.0)
        faces = group.entities.grep(Sketchup::Face).select { |f| f.valid? }
        front = select_front_panel_faces(faces)
        return 0 if front.empty?

        bay_w = Constants::GRAPHIC_BAY_MM.mm
        tex_w, tex_h = texture_dims(material, bay_w, height_mm.to_f.mm)
        # Cropped material: this bay owns the full texture → U window 0→tex_w.
        # (Strip math for tests still uses bay_u_window on the *source* image.)
        u0 = 0.0
        u1 = tex_w
        h = tex_h
        path = bay_front_path(flex_angle_deg)
        cum = path_cumulative_lengths(path)
        total = cum.empty? ? 0.0 : cum.last
        total = bay_w if total < 1e-9

        painted = 0
        front.each do |face|
          painted += 1 if paint_front_face!(face, material, u0, u1, h, path, cum, total)
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

      def select_front_panel_faces(faces)
        faces.select do |f|
          next false unless f.valid?
          n = f.normal
          next false if n.z.abs >= 0.40
          face_area_mm2(f) >= MIN_FRONT_AREA_MM2
        end
      end

      def face_area_mm2(face)
        face.area.to_f * 25.4 * 25.4
      rescue StandardError
        0.0
      end

      def paint_front_face!(face, material, u0, u1, h, path, cum, total)
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
