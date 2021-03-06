require 'fastimage'

module Frameit
  class Editor
    module Color
      BLACK = "SpaceGray"
      SILVER = "Slvr"
    end

    module Orientation
      PORTRAIT = "Vert"
      LANDSCAPE = "Horz"
    end


    def initialize
      converter = FrameConverter.new
      unless converter.frames_exist?
        # First run
        converter.run
      else
        # Just make sure, the PSD files are converted to PNG
        converter.convert_frames
      end
    end

    def run(path, color = Color::BLACK)
      @color = color

      Dir.glob("#{path}/**/*.{png,PNG}").each do |screenshot|
        next if screenshot.include?"_framed.png"
        begin
          template_path = get_template(screenshot)
          if template_path
            template = MiniMagick::Image.open(template_path)
            image = MiniMagick::Image.open(screenshot)

            offset_information = image_offset(screenshot)
            raise "Could not find offset_information for '#{screenshot}'" unless (offset_information and offset_information[:width])
            width = offset_information[:width]
            image.resize width

            result = template.composite(image) do |c|
              c.compose "Over"
              c.geometry offset_information[:offset]
            end

            output_path = screenshot.gsub('.png', '_framed.png').gsub('.PNG', '_framed.png')
            result.write output_path
            Helper.log.info "Successfully framed screenshot at path '#{output_path}'".green
          end
        rescue SystemExit, Interrupt => ex
          raise ex # system interrupted exception (ctrl + C)
        rescue Exception => ex
          Helper.log.error ex
        end
      end
    end

    # This will detect the screen size and choose the correct template
    def get_template(path)
      parts = [
        device_name(screen_size(path)),
        orientation_name(path),
        @color
      ]

      templates_path = [ENV['HOME'], FrameConverter::FRAME_PATH].join('/')
      templates = Dir["#{templates_path}/**/#{parts.join('_')}*.png"]

      if templates.count == 0
        if screen_size(path) == Deliver::AppScreenshot::ScreenSize::IOS_35
          Helper.log.warn "Unfortunately 3.5\" device frames were discontinued. Skipping screen '#{path}'".yellow
        else
          Helper.log.error "Could not find a valid template for screenshot '#{path}'".red
          Helper.log.error "You can download new templates from '#{FrameConverter::DOWNLOAD_URL}'"
          Helper.log.error "and store them in '#{templates_path}'"
          Helper.log.error "Missing file: '#{parts.join('_')}.psd'".red
        end
        return nil
      else
        # Helper.log.debug "Found template '#{templates.first}' for screenshot '#{path}'"
        return templates.first.gsub(" ", "\ ")
      end
    end

    private
      def screen_size(path)
        Deliver::AppScreenshot.calculate_screen_size(path)
      end

      def device_name(screen_size)
        size = Deliver::AppScreenshot::ScreenSize
        case screen_size
          when size::IOS_55
            return 'iPhone_6_Plus'
          when size::IOS_47
            return 'iPhone_6'
          when size::IOS_40
            return 'iPhone_5s'
          when size::IOS_IPAD
            return 'iPad_mini'
        end
      end

      def orientation_name(path)
        size = FastImage.size(path)
        return Orientation::PORTRAIT if size[0] < size[1]
        return Orientation::LANDSCAPE
      end

      def image_offset(path)
        size = Deliver::AppScreenshot::ScreenSize
        case orientation_name(path)
          when Orientation::PORTRAIT
            case screen_size(path)
              when size::IOS_55
                return { 
                  offset: '+42+147',
                  width: 539
                }
              when size::IOS_47
                return {
                  offset: '+41+154',
                  width: 530
                }
              when size::IOS_40
                return {
                  offset: "+54+197",
                  width: 543
                }
              when size::IOS_IPAD
                return {
                  offset: '+50+134',
                  width: 792
                }
            end
          when Orientation::LANDSCAPE
            case screen_size(path)
              when size::IOS_55
                return { 
                  offset: "+146+41",
                  width: 960
                }
              when size::IOS_47
                return {
                  offset: "+153+41",
                  width: 946
                }
              when size::IOS_40
                return {
                  offset: "+201+48",
                  width: 970
                }
              when size::IOS_IPAD
                return {
                  offset: '+133+50',
                  width: 1058
                }
            end
        end
      end
  end
end