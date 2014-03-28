# Copyright 2006-2012 Michel Casabianca <michel.casabianca@gmail.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'rubygems'
require 'bee_build'
require 'bee_task_package'
require 'bee_util'
require 'bee_version_dependant'
require 'erb'
require 'fileutils'
require 'net/smtp'
require 'highline/import'
require 'net/ftp'

module Bee
  
  module Task
  
    # Package for default tasks (tasks with no package).
    class Default < Package
      
      ######################################################################
      #                        MISCELLANEOUS TASKS                         #
      ######################################################################
    
      # Print a message on console. If message is not a string, this task
      # outputs the inspected value of the object.
      # 
      # - message: message to print.
      # 
      # Example
      # 
      #  - echo: "Hello World!"
      def echo(message)
        message = '' if message == nil
        case message
        when String
          puts message
        else
          puts message.inspect
        end
      end

      # Alias for echo.
      alias :print :echo

      # Wait for a given amount of time.
      # 
      # - time: time to wait, in seconds, as an integer or float.
      # 
      # Example
      # 
      #  - sleep: 3.5
      def sleep(time)
        error "sleep parameter must be a float or a integer" if
          not time.kind_of?(Numeric)
        seconds = time.to_f
        puts "Waiting #{time} seconds..."
        Kernel.sleep seconds
      end

      # Alias for sleep.
      alias :wait :sleep

      # Prompt the user for the value of a given property matching a pattern.
      # 
      # - message: message to print at prompt. Should include a description
      #   of the expected pattern.
      # - property: the name of the property to set.
      # - default: default value if user doesn't type anything. Written
      #   into square brakets after prompt message. Optional.
      # - pattern: a Ruby pattern for prompted value. If this pattern is not
      #   matched, this task will prompt again. Optional, if no pattern is
      #   given, any value is accepted.
      # - error: the error message to print when pattern is not matched.
      # - attempts: number of allowed attempts. Optional, defaults to 0, which
      #   means an unlimited number of attempts.
      # - echo: the character to echo while typing. Useful for passwords,
      #   echoing '*' for instance.
      #
      # Example
      #
      #  - prompt:
      #      message:  "Enter your age"
      #      property: "age"
      #      default:  "18"
      #      pattern:  "^\\d+$"
      #      error:    "Age must be a positive integer"
      def prompt(params)
        params_desc = {
          :message  => { :mandatory => true,  :type => :string },
          :property => { :mandatory => true,  :type => :string },
          :default  => { :mandatory => false, :type => :string },
          :pattern  => { :mandatory => false, :type => :string },
          :error    => { :mandatory => false, :type => :string },
          :attempts => { :mandatory => false, :type => :integer,
                         :default   => 0 },
          :echo     => { :mandatory => false, :type => :string,
                         :default   => false }
        }
        check_parameters(params, params_desc)
        message = params[:message]
        property = params[:property]
        default = params[:default]
        pattern = params[:pattern]
        error = params[:error]
        attempts = params[:attempts]
        echo_char = params[:echo]
        message << " [#{default}]" if default
        message << ': '
        ok = false
        nb_attempts = 1
        while not (ok or (nb_attempts > attempts and attempts != 0))
          if echo_char
            value = ask(message) {|q| q.echo=echo_char}
          else
            value = ask(message)
          end
          value = default if default and value.length == 0
          if pattern
            if value =~ /#{pattern}/
              ok = true
            elsif error
              puts error
            end
          else
            ok = true
          end
          nb_attempts += 1
        end
        error "Failed to obtain a matching prompt" if not ok
        @build.context.set_property(property, value)
      end

      # Throw a build error with a given message.
      #
      # - message: the error message. Will be printed on the console as the
      #   build failure reason.
      #
      # Example
      #
      #   - if: "not File.exists?('/etc/config')"
      #     then:
      #     - throw: "No /etc/config file found!"
      def throw(message)
        error "throw parameter must be a string" if not message.kind_of?(String)
        error message
      end

      # Alias for throw.
      alias :raise :throw

      # Get a given URL and store its content in a given file. Parameters
      # is a Hash with following entries:
      #
      # - url: the URL to get.
      # - dest: destination file. Optional, defaults to retrieved file name
      #   in current directory. If destination is a directory, file is saved
      #   in destination directory with the name of the retrieved file.
      # - prop: Property to set with content of the response body. Optional
      #   defaults to output in a file.
      # - limit: the redirections limit. Optional, defaults to 10.
      # - username: username for HTTP basic authentication. Optional.
      # - password: password for HTTP basic authentication. Optional.
      #
      # Example
      #
      #   - get:
      #       url: http://rubyforge.org/frs/download.php/22185/bee-0.4.0.zip
      def http_get(parameters)
        params_desc = {
          :url      => { :mandatory => true,  :type => :string },
          :dest     => { :mandatory => false, :type => :string },
          :prop     => { :mandatory => false, :type => :string },
          :limit    => { :mandatory => false, :type => :integer,
                         :default => 10 },
          :username => { :mandatory => false, :type => :string },
          :password => { :mandatory => false, :type => :string },
        }
        check_parameters(parameters, params_desc)
        url      = parameters[:url]
        dest     = parameters[:dest]
        prop     = parameters[:prop]
        username = parameters[:username]
        password = parameters[:password]
        if not dest and not prop
          destination = File.basename(url)
        elsif dest and File.directory?(dest)
          destination = File.join(dest, File.basename(url))
        elsif dest
          destination = dest
        else
          destination = nil
        end
        limit = parameters[:limit]
        puts "Getting URL '#{url}'..."
        begin
          content = Util::fetch(url, limit, username, password)
        rescue Exception
          error "Error getting URL: #{$!}"
        end
        if destination
          todir = File.dirname(destination)
          begin
            FileUtils.makedirs(todir) if not File.exists?(todir)
            File.open(destination, 'w') { |file| file.write(content) }
          rescue Exception
            error "Error saving file: #{$!}"
          end
        end
        if prop
          @build.context.set_property(prop, content)
        end
      end
      
      # Send an email using SMTP.
      #
      # - from: The sender of the email.
      # - to: Recipient of the email. This may be a list of recipients.
      # - subject: The subject of the email.
      # - message: The body of the email.
      # - smtp: The address of the SMTP server.
      # - encoding: The message encoding. Defaults to ASCII.
      #
      # Example
      #
      #   - mail:
      #       from:    "foo@bee.com"
      #       to:      "bar@bee.com"
      #       subject: "Bee Release 0.6.2"
      #       message: "Hi! There is a new Bee release!"
      #       smtp:    "smtp.bee.com"
      def mail(parameters)
        params_desc = {
          :from     => { :mandatory => true,  :type => :string },
          :to       => { :mandatory => true,  :type => :string_or_array },
          :subject  => { :mandatory => true,  :type => :string },
          :message  => { :mandatory => true,  :type => :string },
          :smtp     => { :mandatory => true,  :type => :string },
          :encoding => { :mandatory => false, :type => :string,
                         :default   => 'UTF-8'}
        }
        check_parameters(parameters, params_desc)
        from     = parameters[:from]
        to       = Array(parameters[:to])
        subject  = parameters[:subject]
        message  = parameters[:message]
        smtp     = parameters[:smtp]
        encoding = parameters[:encoding]
        body = <<EOF
MIME-Version: 1.0
Content-Type: text/plain; charset=#{encoding}
From: #{from}
To: #{to.join(', ')}
Subject: #{subject}

#{message}
EOF
        puts "Sending email about '#{subject}'..."
        begin
          Net::SMTP.start(smtp) do |smtp_server|
            smtp_server.send_message(body, from, to)
          end
        rescue Exception
          error "Error sending email: #{$!}"
        end
      end

      ######################################################################
      #                         FILE RELATED TASKS                         #
      ######################################################################
    
      # Print contents of a given file on the console. Parameter is the name
      # of the file to output, as a String.
      # 
      # Example
      # 
      #  - cat: "doc/welcome-message.txt"
      def cat(file)
        error "Parameter must be a string" unless file.kind_of?(String)
        error "File '#{file}' not a regular file or not readable" unless 
          File.file?(file) and File.readable?(file)
        puts File.read(file).strip
      end

      # Change working directory. This change will persist for all tasks in
      # the current target. Entering a new target, working directory will
      # recover its default value, which is the directory of the build file
      # (or property 'base'). Parameter is a String with directory to change
      # to.
      # 
      # Example
      # 
      #  - cd: "build"
      def cd(dir)
        error "cd parameter must be a string" unless dir.kind_of?(String)
        error "cd parameter must be a readable existing directory" unless
          File.directory?(dir) and File.executable?(dir)
        puts "Changing directory to '#{dir}'"
        Dir.chdir(dir)
      end

      # Put working directory in a given property. Parameter is the name of
      # the property to write current directory into.
      #
      # Example
      #
      #   - pwd: current_dir
      def pwd(property)
        error "pwd parameter must be a string" unless property.kind_of?(String)
        pwd = FileUtils.pwd
        @build.context.set_property(property, pwd)
      end

      # Make a symbolic link from a source file to a destination one.
      # Parameter is a Hash with following entries:
      #
      # - old: source of the link, as a glob. If there are more than one
      #   file to link, this task will make links 'new/file' for each file
      #   of the glob.
      # - new: destination of the link.
      #
      # Example
      #
      #   - ln:
      #       old: /usr/local
      #       new: /opt
      #
      # Note:
      #
      #   This task is not implemented under Windows.
      def ln(parameters)
        params_desc = {
          :old => { :mandatory => true, :type => :string },
          :new => { :mandatory => true, :type => :string }
        }
        check_parameters(parameters, params_desc)
        old = parameters[:old]
        new = parameters[:new]
        files = Dir.glob(old)
        files = files.first if files.length == 1
        puts "Linking #{files.length} file(s) to '#{new}'"
        begin
          FileUtils.ln_s(files, new)
        rescue Exception
          error "Error making the link: #{$!}"
        end
      end

      # Alias for ln.
      alias :link :ln

      # Change permissions for a set of files. Parameters is a Hash with
      # following entries:
      #
      # - files: files to change permissions for, as a glob.
      # - mode: permissons as an Unix integer (such as 0644 or 0755). Note that
      #   numbers starting with 0 are considered octal, with 0x, they are
      #   supposed to be hexa and in base 10 otherwise.
      # - recursive: tells if should process directories recursively.
      #   Optional, defaults to 'false'.
      #
      # Example:
      #
      #   - chmod:
      #       files: /usr/local/bin/*
      #       mode:  0755
      #
      # Note:
      #
      #   This task is not implemented under Windows.
      def chmod(parameters)
        params_desc = {
          :files     => { :mandatory => true,  :type => :string_or_array },
          :mode      => { :mandatory => true,  :type => :integer },
          :recursive => { :mandatory => false, :type => :boolean,
                          :default   => false }
        }
        check_parameters(parameters, params_desc)
        files = parameters[:files]
        mode = parameters[:mode]
        recursive = parameters[:recursive]
        files = Dir.glob(files)
        if files.length > 0
          puts "Changing permissions for #{files.length} file(s) to '#{mode}'"
          begin
            if recursive
              FileUtils.chmod_R(mode, files)
            else
              FileUtils.chmod(mode, files)
            end
          rescue Exception
            error "Error changing permissions: #{$!}"
          end
        end
      end

      # Change owner and group for a set of files. Parameters is a Hash with
      # following entries:
      #
      # - files: files to change owner for, as a glob.
      # - user: the user to change for, may be a name or an ID (integer). If
      #   not set, the user is not changed.
      # - group: the group to change for, may be a name or an ID (integer). If
      #   not set, the group is not changed.
      # - recursive: tells if should process directories recursively.
      #   Optional, defaults to 'false'.
      #
      # Example:
      #
      #   - chown:
      #       files:     /home/casa
      #       user:      casa
      #       group:     staff
      #       recursive: true
      #
      # Note:
      #
      #   This task is not implemented under Windows.
      def chown(parameters)
        params_desc = {
          :files     => { :mandatory => true,  :type => :string_or_array },
          :user      => { :mandatory => false, :type => :string_or_integer },
          :group     => { :mandatory => false, :type => :string_or_integer },
          :recursive => { :mandatory => false, :type => :boolean,
                          :default   => false }
        }
        check_parameters(parameters, params_desc)
        files = parameters['files']
        user = parameters['user']
        group = parameters['group']
        recursive = parameters['recursive']
        files = Dir.glob(files)
        if files.length > 0
          puts "Changing owner of #{files.length} file(s) to '#{user}/#{group}'"
          begin
            if recursive
              FileUtils.chown_R(user, group, files)
            else
              FileUtils.chown(user, group, files)
            end
          rescue Exception
            error "Error changing owner: #{$!}"
          end
        end
      end

      # Make a directory, and parent directories if necessary. Doesn't
      # complain if directory already exists. Parameter is directory to
      # create as a String or a list of directories as an Array of Strings.
      # 
      # Example
      # 
      #  - mkdir: "foo/bar"
      def mkdir(dirs)
        error "mkdir parameter must a String or an array of Strings" unless
          dirs.kind_of?(String) or dirs.kind_of?(Array)
        dirs = Array(dirs)
        for dir in dirs
          error "mkdir parameter must a String or an array of Strings" unless
            dir.kind_of?(String)
          puts "Creating directory '#{dir}'"
          begin
            FileUtils.makedirs(dir)
          rescue Exception
            error "Error creating directory '#{dir}': #{$!}"
          end
        end
      end

      # Copy files or directories to destination file or directory. Parameter 
      # is a Hash with following entries:
      # 
      # - src: glob or list of globs for source files or directories to copy.
      #   Included source directories are copied recursively.
      # - dest: destination file or directory.
      # 
      # Example
      # 
      #  - cp:
      #      src:  "img/*"
      #      dest: :doc
      def cp(params)
        params_desc = {
          :src  => { :mandatory => true, :type => :string_or_array },
          :dest => { :mandatory => true, :type => :string }
        }
        check_parameters(params, params_desc)
        src = params['src']
        dest = params['dest']
        src = Array(src).map { |s| Dir.glob(s) }.flatten.uniq
        src = src.first if src.length == 1
        if src.kind_of?(Array)
          nb_copies = src.length
        else
          nb_copies = 1
        end
        puts "Copying #{nb_copies} file(s) to '#{dest}'"
        begin
          FileUtils.cp_r(src, dest)
        rescue Exception
          error "Error copying file(s): #{$!}"
        end
      end

      # Moves files or directories to destination file or directory. Parameter 
      # is a Hash with following entries:
      # 
      # - src: glob or list of globs for source files or directories to move.
      #   Included source directories are moved recursively.
      # - dest: destination file or directory.
      # 
      # Example
      # 
      #  - mv:
      #      src:  "**/*~"
      #      dest: :trash
      def mv(params)
        params_desc = {
          :src  => { :mandatory => true, :type => :string_or_array },
          :dest => { :mandatory => true, :type => :string }
        }
        check_parameters(params, params_desc)
        src = params['src']
        dest = params['dest']
        src = Array(src).map { |s| Dir.glob(s) }.flatten.uniq
        src = src.first if src.length == 1
        if src.kind_of?(Array)
          nb_moves = src.length
        else
          nb_moves = 1
        end
        puts "Moving #{nb_moves} file(s) to '#{dest}'"
        begin
          FileUtils.mv(src, dest)
        rescue Exception
          error "Error moving file(s): #{$!}"
        end
      end

      # Copy filtered files. Parameter is a hash with following entries:
      #
      # - root: root directory for files to copy. Optional, defaults to current
      #   directory.
      # - includes: list of globs for files to copy. Optional, defaults to 
      #   '**/*' to include all files recursively.
      # - excludes: list of globs for files to exclude from copy. Optional,
      #   default to nil to exclude no file.
      # - dotmatch: tells if joker matches dot files. Optional, defaults to
      #   false.
      # - flatten: tells if included files should be copied in destination
      #   directory, ignoring their subdirectory. Optional, defaults to false.
      # - dest: destination directory for the copy, must be an existing
      #   directory.
      # - lenient: tells if copy is lenient, which will silently succeed on
      #   errors (for instance if root or destination directory don't exist).
      #   Optional, defaults to false.
      #
      # Example:
      #
      # To copy all files from directory 'src', except those living in 'CVS'
      # directories, into directory 'destination', you could write:
      #
      #   - copy:
      #       root:     src
      #       includes: **/*
      #       excludes: **/CVS/**/*
      #       dest:     destination
      # 
      # Note: this task only deals with files. Thus, 'includes' and 'excludes'
      # globs should be ones for files.
      def copy(params)
        # check parameters and set default values
        params_desc = {
          :root     => { :mandatory => false, :type => :string },
          :includes => { :mandatory => false, :type => :string_or_array },
          :excludes => { :mandatory => false, :type => :string_or_array },
          :dotmatch => { :mandatory => false, :type => :boolean },
          :dest     => { :mandatory => true,  :type => :string },
          :flatten  => { :mandatory => false, :type => :boolean,
                         :default   => false },
          :lenient  => { :mandatory => false, :type => :boolean,
                         :default   => false }
        }
        check_parameters(params, params_desc)
        root     = params[:root]
        includes = params[:includes]
        excludes = params[:excludes]
        dotmatch = params[:dotmatch]
        dest     = params[:dest]
        flatten  = params[:flatten]
        lenient  = params[:lenient]
        # check that destination is an existing directory
        if not (File.exists?(dest) and File.directory?(dest))
          if lenient
            return
          else
            error "copy 'dest' parameter must be an existing directory"
          end
        end
        root = '.' if root == nil
        dotmatch = false if dotmatch == nil
        if not (File.exists?(root) and File.directory?(root))
          if lenient
            return
          else
            error "copy 'root' parameter must be an existing directory"
          end
        end
        files = filter_files(root, includes, excludes, dotmatch)
        copy_files(root, files, dest, flatten)
      end

      # Move filtered files. Parameter is a hash with following entries:
      #
      # - root: root directory for files to move. Optional, defaults to
      #   current directory.
      # - includes: list of globs for files to move. Optional, defaults to 
      #   '**/*' to include all files recursively.
      # - excludes: list of globs for files to exclude from move. Optional,
      #   default to nil to exclude no file.
      # - flatten: tells if included files should be moved to destination
      #   directory, ignoring their subdirectory. Optional, defaults to false.
      # - dotmatch: tells if joker matches dot files. Optional, defaults to
      #   false.
      # - lenient: tells if move is lenient, which will silently succeed on
      #   errors (for instance if root or destination directory don't exist).
      #   Optional, defaults to false.
      #
      # Example:
      #
      # To move all files from directory 'src', except those living in 'CVS'
      # directories, into directory 'destination', you could write:
      #
      #   - move:
      #       root:     src
      #       includes: **/*
      #       excludes: **/CVS/**/*
      #       dest:     destination
      #
      # Note: this task only deals with files. Thus, 'includes' and 'excludes'
      # globs should be ones for files and directories from root will not
      # be affected by this task.
      def move(params)
        # check parameters and set default values
        params_desc = {
          :root     => { :mandatory => false, :type => :string,
                         :default   => '.' },
          :includes => { :mandatory => false, :type => :string_or_array },
          :excludes => { :mandatory => false, :type => :string_or_array },
          :dest     => { :mandatory => true,  :type => :string },
          :flatten  => { :mandatory => false, :type => :boolean,
                         :default   => false },
          :dotmatch => { :mandatory => false, :type => :boolean,
                         :default   => false },
          :lenient  => { :mandatory => false, :type => :boolean,
                         :default   => false }
        }
        check_parameters(params, params_desc)
        root     = params[:root]
        includes = params[:includes]
        excludes = params[:excludes]
        dest     = params[:dest]
        flatten  = params[:flatten]
        dotmatch = params[:dotmatch]
        lenient  = params[:lenient]
        # check that root and dest are existing directories
        if not (File.exists?(root) and File.directory?(root))
          if lenient
            return
          else
            error "move 'root' parameter must be an existing directory"
          end
        end
        if not (File.exists?(dest) and File.directory?(dest))
          if lenient
            return
          else
            error "move 'dest' parameter must be an existing directory"
          end
        end
        # select files and make move
        files = filter_files(root, includes, excludes, dotmatch)
        puts "Moving #{files.length} file(s) to '#{dest}'"
        for file in files
          from_file = File.join(root, file)
          if flatten
            to_file = File.join(dest, File.basename(file))
          else
            to_file = File.join(dest, file)
          end
          to_dir    = File.dirname(to_file)
          FileUtils.makedirs(to_dir) if not File.exists?(to_dir)
          FileUtils.mv(from_file, to_file)
        end
      end

      # Delete files for a given glob or list of globs. Parameter is a glob or 
      # list of globs for files to delete. This task will raise an error if
      # told to delete a directory. Use task 'rmrf' to do so.
      # 
      # Example
      # 
      #  - rm: ["**/*~", "**/.DS_Store"]
      def rm(globs)
        error "rm parameter is a String or Array of Strings" unless
          globs.kind_of?(String) or globs.kind_of?(Array)
        globs = Array(globs)
        for glob in globs
          error "rm parameter is a String or Array of Strings" unless
            glob.kind_of?(String)
          files = Dir.glob(glob)
          size = (files.kind_of?(Array) ? files.size : 1)
          puts "Deleting #{size} file(s)" if files.length > 0
          for file in files
            begin
              FileUtils.rm(file)
            rescue Exception
              error "Error deleting files: #{$!}"
            end
          end
        end
      end

      # Delete files and directories recursively. Parameter is a glob or list
      # of globs for files and directories to delete.
      # 
      # Example
      # 
      #  - rmrf: :build
      def rmrf(globs)
        error "rmrf parameter is a String or an Array of Strings" unless
          globs.kind_of?(String) or globs.kind_of?(Array)
        globs = Array(globs)
        for glob in globs
          error "rmrf parameter is a String or an Array of Strings" unless
            glob.kind_of?(String)
          dirs = Dir.glob(glob)
          size = (dirs.kind_of?(Array) ? dirs.size : 1)
          puts "Deleting #{size} directory(ies)" if dirs.length > 0
          for dir in dirs
            begin
              FileUtils.rm_rf(dir)
            rescue Exception
              error "Error deleting directory(ies): #{$!}"
            end
          end
        end
      end

      # Alias for rmrf.
      alias :rmdir :rmrf

      # Update modification time and access time of files in a list. Files
      # are created if they don't exist. Parameter is a glob or list of
      # globs for files to touch.
      #
      # Example
      # 
      #   - touch: '#{target}/classes/**/*.class'
      def touch(globs)
        error "touch parameter is a String or an Array of Strings" unless
          globs.kind_of?(String) or globs.kind_of?(Array)
        globs = Array(globs)
        files = []
        for glob in globs
          error "touch parameter is a String or an Array of Strings" unless
            glob.kind_of?(String)
          new_files = Dir.glob(glob)
          if new_files.length == 0
            files << glob
          else
            files += new_files
          end
        end
        files.uniq!
        size = (files.kind_of?(Array) ? files.size : 1)
        puts "Touching #{size} file(s)" if size > 0
        begin
          FileUtils.touch(files)
        rescue Exception
          error "Error touching file(s): #{$!}"
        end
      end

      # Find files for a glob or list of globs and store list in a property. 
      # Parameter is a Hash with entries:
      # 
      # - root: root directory for file search. Defaults to '.' (current
      #   directory).
      # - includes: glob or list of globs for files to look for. Defaults to
      #   '**/*' to include all files recursively.
      # - excludes: glob or list of globs for files to exclude from search.
      #   Defaults to nil to exclude no file.
      # - dotmatch: tells if joker matches dot files. Optional, defaults to
      #   false.
      # - property: name of the property to set.
      # - join: a character used to join the list in a string. Defaults
      #   to nil so that list is not joined.
      # 
      # Example
      #
      # To find all PNG in files in 'img' directory, and store the list in
      # property image_files, one could write:
      # 
      #  - find:
      #      root:     "img"
      #      includes: "**/*.png"
      #      property: "image_files"
      def find(params)
        params_desc = {
          :root     => { :mandatory => false, :type => :string,
                         :default => '.' },
          :includes => { :mandatory => false, :type => :string_or_array },
          :excludes => { :mandatory => false, :type => :string_or_array },
          :property => { :mandatory => true,  :type => :string },
          :dotmatch => { :mandatory => false, :type => :boolean,
                         :default => false },
          :join     => { :mandatory => false, :type => :string }
        }
        check_parameters(params, params_desc)
        root     = params[:root]
        includes = params[:includes]
        excludes = params[:excludes]
        property = params[:property]
        dotmatch = params[:dotmatch]
        join     = params[:join]
        files = filter_files(root, includes, excludes, dotmatch)
        if join
          files = files.join(join)
        end
        @build.context.set_property(property, files)
      end

      # Load a YAML file in a given property.
      # 
      # - file: the YAML file name to load.
      # - prop: the property name to set with YAML parsed content.
      # 
      # Example
      #
      #  - yaml_load:
      #      file: "my_list.yml"
      #      prop: "my_list"
      def yaml_load(params)
        params_desc = {
          :file  => { :mandatory => true, :type => :string },
          :prop  => { :mandatory => true, :type => :string },
        }
        check_parameters(params, params_desc)
        file = params[:file]
        prop = params[:prop]
        error "YAML file '#{file}' not found" if not File.exists?(file)
        script = "#{prop} = YAML.load(File.read('#{file}'))"
        begin
          @build.context.evaluate_script(script)
        rescue Exception
          error "Error loading YAML file '#{file}': #{$!}"
        end
      end      

      # Dump the content of a given property into a YAML file.
      # 
      # - prop: the property to dump.
      # - file: the YAML file name to dump into.
      # 
      # Example
      #
      #  - yaml_dump:
      #      prop: "my_list"
      #      file: "my_list.yml"
      def yaml_dump(params)
        params_desc = {
          :prop  => { :mandatory => true, :type => :string },
          :file  => { :mandatory => true, :type => :string }
        }
        check_parameters(params, params_desc)
        prop = params[:prop]
        file = params[:file]
        script = "File.open('#{file}', 'w') {|f| f.write(YAML.dump(#{prop}))}"
        begin
          @build.context.evaluate_script(script)
        rescue Exception
          error "Error dumping YAML file '#{file}': #{$!}"
        end
      end      

      ######################################################################
      #                        RUBY RELATED TASKS                          #
      ######################################################################
    
      # Tests a required library and prints an error message if import
      # fails. Parameter is a Hash with entries:
      #
      # - library: required library (as in require call).
      # - message: error message to print if require fails.
      #
      # Example
      #
      #  - required:
      #      library: foo
      #      message: >
      #        Library foo must be installed (gem install foo) to run
      #        task bar.
      def required(params)
        require 'rubygems'
        require 'rubygems/gem_runner'
        params_desc = {
          :library => { :mandatory => true, :type => :string },
          :message => { :mandatory => true, :type => :string }
        }
        check_parameters(params, params_desc)
        library = params[:library]
        message = params[:message]
        available = Bee::VersionDependant::gem_available?(library)
        error message if not available
      end

      # Run Ruby unit tests listed as a glob or list of globs in a given
      # directory (that defaults to current one). Parameter is a Hash with
      # following entries:
      # 
      # - root: root directory for files to include. Defaults to current
      #   directory.
      # - includes: glob or list of globs for unit test files to run.
      #   Defaults to '**/*' to include all files recursively.
      # - excludes: glob or list of globs for unit test files to exclude.
      #   Defaults to nil to exclude no file.
      # - dotmatch: tells if joker matches dot files. Optional, defaults to
      #   false.
      # - dir: directory where to run unit tests.
      # 
      # Example
      # 
      #  - find:
      #      root:     :test
      #      includes: "**/tc_*.rb"
      #      dir:      "test"
      #
      # Notes
      #
      # For ruby 1.9 and later, you must install gem 'test-unit' to run this
      # task.
      def test(params)
        require 'test/unit'
        params_desc = {
          :root     => { :mandatory => false, :type => :string,
                         :default   => '.' },
          :includes => { :mandatory => true,  :type => :string },
          :excludes => { :mandatory => false, :type => :string },
          :dotmatch => { :mandatory => false, :type => :boolean,
                         :default => false },
          :dir      => { :mandatory => false, :type => :string,
                         :default => '.' }
        }
        check_parameters(params, params_desc)
        root     = params[:root]
        includes = params[:includes]
        excludes = params[:excludes]
        dotmatch = params[:dotmatch]
        dir      = params[:dir]
        error "Test directory '#{dir}' not found" if 
          not (File.exists?(dir) and File.directory?(dir))
        files = filter_files(root, includes, excludes, dotmatch)
        files.map! { |file| File.expand_path(File.join(root, file)) }
        size = (files.kind_of?(Array) ? files.size : 1)
        puts "Running #{size} unit test(s)"
        for file in files
          load file
        end
        old_dir = Dir.pwd
        begin
          Dir.chdir(dir)
          if Bee::VersionDependant::ruby_lower_than('1.9.2')
            runner = Test::Unit::AutoRunner.new(false)
          else
            runner = MiniTest::Unit.new()
          end
          ok = runner.run
          error "Test failure" if not ok
        ensure
          Dir.chdir(old_dir)
        end
      end

      # Run an ERB file or source in bee context and store result in a file or
      # property. Parameter is a Hash with following entries:
      # 
      # - source: ERB source text (if no 'src').
      # - src: ERB file name (if no 'source').
      # - dest: file where to store result (if no 'property').
      # - property: property name where to store result (if no 'dest').
      # - options: ERB options, a String containing one or more of the
      #   following modifiers:
      #   %  enables Ruby code processing for lines beginning with %
      #   <> omit newline for lines starting with <% and ending in %>
      #   >  omit newline for lines ending in %>
      #
      # For more information ebout ERB syntax, please see documentation at:
      # http://www.ruby-doc.org/stdlib/libdoc/erb/rdoc/.
      # 
      # Example
      # 
      #  - erb: { src: "gem.spec.erb", dest: "gem.spec" }
      # 
      # Notes
      # 
      # In these ERB files, you can access a property _foo_ writing:
      # 
      #  <p>Hello <%= foo %>!</p>
      def erb(params)
        params_desc = {
          :source   => { :mandatory => false, :type => :string },
          :src      => { :mandatory => false, :type => :string },
          :dest     => { :mandatory => false, :type => :string },
          :property => { :mandatory => false, :type => :string },
          :options  => { :mandatory => false, :type => :string }
        }
        check_parameters(params, params_desc)
        source   = params[:source]
        src      = params[:src]
        dest     = params[:dest]
        property = params[:property]
        options  = params[:options]
        error "Must pass one of 'source' or 'src' parameters to erb task" if
          not source and not src
        error "Must pass one of 'dest' or 'property' parameters to erb task" if
          not dest and not property
        error "erb src file '#{src}' not found" if src and
          (not File.exists?(src) or not File.file?(src) or
           not File.readable?(src))
        # load ERB source
        erb_source = source||File.open(src, 'r') {|f| f.read}
        if options
          template = ERB.new(erb_source, 0, options)
        else
          template = ERB.new(erb_source)
        end
        if src
          puts "Processing ERB '#{src}'"
        else
          puts "Processing ERB"
        end
        begin
          result = template.result(@build.context.context_binding)
        rescue Exception
          error "Error processing ERB: #{$!}"
        end
        # write result in file or set property
        if dest
          begin
            File.open(dest, 'w') { |file| file.write(result) }
          rescue Exception
            error "Error writing ERB result in file: #{$!}"
          end
        else
          @build.context.set_property(property, result)
        end
      end
      
      # Generate RDoc documentation for a given list of globs to include or
      # exclude and a destination directory. Parameter is a Hash with following
      # entries:
      # 
      # - root: root directory for files to include. Defaults to current
      #   directory.
      # - includes: glob or list of globs for files or directories to document.
      #   Defaults to '**/*' to include all files.
      # - excludes: glob or list of globs for files or directories that should
      #   not be documented. Defaults to nil to exclude no file.
      # - dotmatch: tells if joker matches dot files. Optional, defaults to
      #   false.
      # - dest: destination directory for generated documentation.
      # - options: additional options as a string or list of strings.
      # 
      # Example
      # 
      #  - rdoc:
      #      includes: ["README", "LICENSE", "#{src}/**/*"]
      #      dest: :api
      def rdoc(params)
        require 'rdoc/rdoc'
        params_desc= {
          :root     => { :mandatory => false, :type => :string },
          :includes => { :mandatory => true,  :type => :string_or_array },
          :excludes => { :mandatory => false, :type => :string_or_array },
          :dotmatch => { :mandatory => false, :type => :boolean,
                         :default   => false },
          :dest     => { :mandatory => true,  :type => :string },
          :options  => { :mandatory => false, :type => :string_or_array }
        }
        check_parameters(params, params_desc)
        root     = params[:root]
        includes = params[:includes]
        excludes = params[:excludes]
        dotmatch = params[:dotmatch]
        dest     = params[:dest]
        options  = params[:options]
        files = filter_files(root, includes, excludes, dotmatch)
        command_line = ['-S', '-o', dest]
        command_line += options if options
        command_line += files
        begin
          rdoc = RDoc::RDoc.new
          rdoc.document(command_line)
        rescue Exception
          error "Error generating RDoc: #{$!}"
        end
      end
      
      # Generate a Gem package in current directory, named after the Gem name
      # and version. Parameter is the name of the Gem description file.
      # 
      # Example
      # 
      #  - gem: :gem_spec
      def gem(description)
        require 'rubygems'
        require 'rubygems/gem_runner'
        error "gem parameter must be an existing file" if
          not description.kind_of?(String) or not File.exists?(description)
        arguments = ['build', description]
        begin
          Gem::GemRunner.new.run(arguments)
        rescue Exception
          error "Error generating Gem: #{$!}"
        end
      end
      
      # Run another bee build file.
      # 
      # - file: the build file to run, relative to current build file. 
      #   Optional, defaults to 'build.yml'.
      # - target: target or list of targets to run (default target if omitted).
      # - properties: boolean (true or false) that tells if properties of
      #   current build file should be sent and overwrite those of target
      #   build. Properties modified in child build don't change in parent
      #   one. Defaults to false.
      # 
      # Example
      # 
      #  - bee:
      #      file:       "doc/build.yml"
      #      target:     "pdf"
      #      properties: true
      def bee(parameters)
        # parse parameters
        params_desc = {
          :file       => { :mandatory => false, :type => :string, :default => 'build.yml' },
          :target     => { :mandatory => false, :type => :string_or_array,  :default => '' },
          :properties => { :mandatory => false, :type => :boolean, :default => false }
        }
        check_parameters(parameters, params_desc)
        file = parameters[:file]
        target = parameters[:target]
        properties = parameters[:properties]
        # run target build
        props = {}
        if properties
          for name in @build.context.properties
            props[name] = @build.context.get_property(name)
          end
        end
        begin
          build = Bee::Build.load(file, false, props)
          build.run(target, @build.listener.clone)
        rescue Exception
          error "Error invoking build file '#{file}': #{$!}"
        end
      end

      ######################################################################
      #                            ARCHIVE TASKS                           #
      ######################################################################
    
      # Generate a ZIP archive. Parameter is a Hash with following entries:
      # 
      # - root: root directory for files to include in the archive. Defaults
      #   to '.' for current directory.
      # - includes: glob or list of globs for files to select for the archive.
      #   Defaults to '**/*' to include all files recursively.
      # - excludes: glob or list of globs for files to exclude from the archive.
      #   Defaults to nil to exclude no file.
      # - dotmatch: tells if joker matches dot files. Optional, defaults to
      #   false.
      # - dest: the archive file to generate.
      # - prefix: prefix for archive entries (default to nil).
      # 
      # Example
      # 
      #  - zip:
      #      excludes: ["build/**/*", "**/*~"]
      #      dest:     :zip_archive
      # 
      # Note
      # 
      # If archive already exists, files are added to the archive.
      def zip(parameters)
        require 'zip/zip'
        params_desc = {
          :root     => { :mandatory => false, :type => :string },
          :includes => { :mandatory => false, :type => :string_or_array,
                         :default   => "**/*"},
          :excludes => { :mandatory => false, :type => :string_or_array,
                         :default => nil },
          :dotmatch => { :mandatory => false, :type => :boolean,
                         :default => false },
          :dest     => { :mandatory => true,  :type => :string },
          :prefix   => { :mandatory => false, :type => :string }
        }
        check_parameters(parameters, params_desc)
        root     = parameters[:root]
        includes = parameters[:includes]
        excludes = parameters[:excludes]
        dotmatch = parameters[:dotmatch]
        dest     = parameters[:dest]
        prefix   = parameters[:prefix]
        files = filter_files(root, includes, excludes, dotmatch)
        # build the archive
        puts "Building ZIP archive '#{dest}'"
        begin
          Zip::ZipFile.open(dest, Zip::ZipFile::CREATE) do |zip|
            for file in files
              path = (root == nil ? file : File.join(root, file))
              entry = prefix ? File.join(prefix, file) : file
              puts "Adding '#{entry}'" if @verbose
              zip.add(entry, path)
            end
            zip.close
          end
        rescue Exception
          error "Error building ZIP archive: #{$!}"
        end
      end

      # Extract ZIP archive to a destination directory. Existing extracted
      # files are not overwritten and result in an error. Parameter is a Hash
      # with following entries:
      #
      # - src: archive to extract.
      # - dest: destination directory for extracted files. Optional, defaults
      #   to current directory.
      #
      # Example
      #
      #   - unzip:
      #       src:  myarchive.zip
      #       dest: mydir
      def unzip(parameters)
        require 'zip/zip'
        params_desc = {
          :src  => { :mandatory => true,  :type => :string },
          :dest => { :mandatory => false, :type => :string, :default => '.' }
        }
        check_parameters(parameters, params_desc)
        src  = parameters[:src]
        dest = parameters[:dest]
        error "unzip 'src' parameter must be an readable ZIP archive" unless
          File.exists?(src) and File.readable?(src)
        FileUtils.makedirs(dest) if not File.exists?(dest)
        puts "Extracting ZIP file '#{src}' to '#{dest}'"
        begin
          Zip::ZipFile.foreach(src) do |entry|
            puts "Writing '#{entry}'" if @verbose
            tofile = File.join(dest, entry.name)
            if entry.file?
              dir = File.dirname(tofile)
              FileUtils.makedirs(dir) if not File.exists?(dir)
              entry.extract(tofile)
            elsif entry.directory?
              FileUtils.makedirs(tofile)
            end
          end
        rescue Exception
          error "Error extracting ZIP archive: #{$!}"
        end
      end
      
      # Generate a TAR archive. Parameter is a Hash with following entries:
      # 
      # - root: root directory for files to include. Defaults to current
      #   directory.
      # - includes: glob or list of globs for files to select for the archive.
      #   Defaults to '**/*' to include all files recursively.
      # - excludes: glob or list of globs for files to exclude from the archive.
      #   Defaults to nil to exclude no file.
      # - dotmatch: tells if joker matches dot files. Optional, defaults to
      #   false.
      # - dest: the archive file to generate.
      # 
      # Example
      # 
      #  - tar:
      #      includes: "**/*"
      #      excludes: ["build", "build/**/*", "**/*~"]
      #      dest: :tar_archive
      # 
      # Note
      # 
      # If archive already exists, it's overwritten.
      def tar(parameters)
        require 'archive/tar/minitar'
        # parse parameters
        params_desc = {
          :root     => { :mandatory => false, :type => :string },
          :includes => { :mandatory => true,  :type => :string_or_array },
          :excludes => { :mandatory => false, :type => :string_or_array,
                         :default => nil },
          :dotmatch => { :mandatory => false, :type => :boolean,
                         :default => false },
          :dest     => { :mandatory => true,  :type => :string }
        }
        check_parameters(parameters, params_desc)
        root     = parameters[:root]
        includes = parameters[:includes]
        excludes = parameters[:excludes]
        dotmatch = parameters[:dotmatch]
        dest     = parameters[:dest]
        files = filter_files(root, includes, excludes, dotmatch)
        # build the archive
        puts "Processing TAR archive '#{dest}'"
        begin
          current_dir = Dir.pwd
          abs_dest = File.expand_path(dest)
          Dir.chdir(root) if root
          Archive::Tar::Minitar::Output.open(abs_dest) do |tarfile|
            for file in files
              puts "Adding '#{file}'" if @verbose
              Archive::Tar::Minitar.pack_file(file, tarfile)
            end
          end
        rescue Exception
          error "Error generating TAR archive: #{$!}"
        ensure
          Dir.chdir(current_dir)
        end
      end
      
      # Generate a GZIP archive for a given file. Parameter is a Hash with
      # following entries:
      # 
      # - src: source file to generate GZIP for.
      # - dest: GZIP file to generate. Defaults to the src file with '.gz'
      #   extension added.
      # 
      # Example
      # 
      #  - gzip:
      #      src: "dist.tar"
      #      dest: "dist.tar.gz"
      def gzip(parameters)
        require 'zlib'
        # parse parameters
        params_desc = {
          :src  => { :mandatory => true,  :type => :string },
          :dest => { :mandatory => false, :type => :string }
        }
        check_parameters(parameters, params_desc)
        src  = parameters[:src]
        dest = parameters[:dest]
        dest = src + '.gz' if not dest
        # compress file
        puts "Processing GZIP archive '#{dest}'"
        begin
          File.open(src) do |input|
            output = Zlib::GzipWriter.new(File.open(dest, 'wb'))
            output.write(input.read)
            output.close
          end
        rescue Exception
          error "Error generating GZIP archive: #{$!}"
        end
      end

      # Expand a GZIP archive for a given file. Parameter is a Hash with
      # following entries:
      # 
      # - src: GZIP file to expand.
      # - dest: destination for expanded file. Destination file can be guessed
      #   (and thus omitted) for src files '.gz', '.gzip' and '.tgz';
      #   corresponding dest for latest will be '.tar'.
      # 
      # Example
      # 
      #  - gunzip:
      #      src: "dist.tar.gz"
      #      dest: "dist.tar"
      def gunzip(parameters)
        require 'zlib'
        # parse parameters
        params_desc = {
          :src  => { :mandatory => true,  :type => :string },
          :dest => { :mandatory => false, :type => :string }
        }
        check_parameters(parameters, params_desc)
        src  = parameters[:src]
        dest = parameters[:dest]
        error "gunzip 'src' parameter must be an readable GZIP archive" unless
          File.exists?(src) and File.readable?(src)
        if not dest
          if src =~ /.*\.gz$/
            dest = src[0..-4]
          elsif src =~ /.*\.gzip$/
            dest = src[0..-6]
          elsif src =~ /.*\.tgz/
            dest = src[0..-5]+'.tar'
          else
            error "gunzip can't guess 'dest' parameter from 'src' file name"
          end
        end
        # expand file
        puts "Expanding GZIP archive '#{dest}'"
        begin
          Zlib::GzipReader.open(src) do |input|
            output = File.open(dest, 'wb')
            output.write(input.read)
            output.close
          end
        rescue Exception
          error "Error expanding GZIP archive: #{$!}"
        end
      end

      # Generate a TAR.GZ archive. Parameter is a Hash with following entries:
      # 
      # - root: root directory for files to include. Defaults to current 
      #   directory.
      # - includes: glob or list of globs for files to select for the archive.
      #   Defaults to '**/*' to include all files recursively.
      # - excludes: glob or list of globs for files to exclude from the archive.
      #   Defaults to nil to exclude no file.
      # - dotmatch: tells if joker matches dot files. Optional, defaults to
      #   false.
      # - dest: the archive file to generate.
      # 
      # Example
      # 
      #  - targz:
      #      excludes: ["build/**/*", "**/*~"]
      #      dest:     :targz_archive
      # 
      # Note
      # 
      # If archive already exists, it's overwritten.
      def targz(parameters)
        require 'archive/tar/minitar'
        require 'zlib'
        # parse parameters
        params_desc = {
          :root     => { :mandatory => false, :type => :string,
                         :default => '.' },
          :includes => { :mandatory => false, :type => :string_or_array,
                         :default => '**/*' },
          :excludes => { :mandatory => false, :type => :string_or_array,
                         :default => nil },
          :dotmatch => { :mandatory => false, :type => :boolean,
                         :default => false },
          :dest     => { :mandatory => true,  :type => :string }
        }
        check_parameters(parameters, params_desc)
        root     = parameters[:root]
        includes = parameters[:includes]
        excludes = parameters[:excludes]
        dotmatch = parameters[:dotmatch]
        dest     = parameters[:dest]
        files = filter_files(root, includes, excludes, dotmatch)
        # build the archive
        puts "Building TARGZ archive '#{dest}'"
        begin
          current_dir = Dir.pwd
          abs_dest = File.expand_path(dest)
          Dir.chdir(root) if root
          Archive::Tar::Minitar::Output.
            open(Zlib::GzipWriter.new(File.open(abs_dest, 'wb'))) do |tgz|
            for file in files
              puts "Adding '#{file}'" if @verbose
              Archive::Tar::Minitar.pack_file(file, tgz)
            end
          end
        rescue Exception
          error "Error generating TARGZ archive: #{$!}"
        ensure
          Dir.chdir(current_dir)
        end
      end

      # Extract TAR archive to a destination directory. Gziped archives are
      # managed if their extension is '.tgz' or '.tar.gz'. Extracted files 
      # are overwritten if they already exist. Parameter is a Hash with
      # following entries:
      #
      # - src: archive to extract.
      # - dest: destination directory for extracted files. Optional, defaults
      #   to current directory.
      #
      # Example
      #
      #   - untar:
      #       src:  myarchive.tar.gz
      #       dest: mydir
      def untar(parameters)
        require 'archive/tar/minitar'
        require 'zlib'
        params_desc = {
          :src  => { :mandatory => true,  :type => :string },
          :dest => { :mandatory => false, :type => :string, :default => '.' }
        }
        check_parameters(parameters, params_desc)
        src  = parameters[:src]
        dest = parameters[:dest]
        error "untar 'src' parameter must be an readable TAR archive" unless
          File.exists?(src) and File.readable?(src)
        FileUtils.makedirs(dest) if not File.exists?(dest)
        puts "Extracting TAR file '#{src}' to '#{dest}'"
        begin
          if src =~ /\.tar\.gz$/ or src =~ /\.tgz$/
            tgz = Zlib::GzipReader.new(File.open(src, 'rb'))
            Archive::Tar::Minitar.unpack(tgz, dest)
          else
            Archive::Tar::Minitar.unpack(src, dest)
          end
        rescue Exception
          error "Error extracting TAR archive: #{$!}"
        end
      end
      
      ######################################################################
      #                             FTP TASKS                              #
      ######################################################################

      # Login to a remote FTP site. Useful to test a connection. Raises a
      # build error if connection fails. Parameter is a hash with following
      # entries:
      #
      # - username: the username to connect to FTP. Defaults to anonymous.
      # - password: the password to connect to FTP. Defaults to no password.
      # - host: the hostname to connect to.
      #
      # Example
      #
      #   - ftp_login:
      #       username: foo
      #       password: bar
      #       host:     example.com
      def ftp_login(params)
        params_desc = {
          :username => { :mandatory => false, :type => :string },
          :password => { :mandatory => false, :type => :string },
          :host     => { :mandatory => true,  :type => :string }
        }
        check_parameters(params, params_desc)
        username = params[:username]
        password = params[:password]
        host     = params[:host]
        begin
          Net::FTP.open(host) do |ftp|
            ftp.login(username, password)
            ftp.close
          end
          puts "Connection to FTP host '#{host}' sucessful"
        rescue Exception
          error "Error connecting to FTP host: #{$!}"
        end
      end

      # Get a file from a remote FTP site. Raises a build error this operation
      # fails. Parameter is a hash with following entries:
      #
      # - username: the username to connect to FTP. Defaults to anonymous.
      # - password: the password to connect to FTP. Defaults to no password.
      # - host: the hostname to connect to.
      # - file: the FTP path to remote file to get.
      # - output: the local path to file to write. Defaults to same file name
      #   in current directory.
      # - binary: sets the binary mode for download. Defaults to true.
      #
      # Example:
      #
      #   - ftp_get:
      #       username: foo
      #       password: bar
      #       host: foo
      #       file: test.txt
      def ftp_get(params)
        params_desc = {
          :username => { :mandatory => false, :type => :string },
          :password => { :mandatory => false, :type => :string },
          :host     => { :mandatory => true,  :type => :string },
          :file     => { :mandatory => true,  :type => :string },
          :output   => { :mandatory => false, :type => :string },
          :binary   => { :mandatory => false, :type => :boolean,
                         :default   => true }
        }
        check_parameters(params, params_desc)
        username = params[:username]
        password = params[:password]
        host     = params[:host]
        file     = params[:file]
        output   = params[:output]||File.basename(file)
        binary   = params[:binary]
        basename = File.basename(file)
        puts "Getting file '#{basename}'..."
        begin
          Net::FTP.open(host) do |ftp|
            ftp.login(username, password)
            if binary
              ftp.getbinaryfile(file, output)
            else
              ftp.gettextfile(file, output)
            end
            ftp.close
          end
        rescue Exception
          error "Error getting file '#{basename}': #{$!}"
        end
      end

      # Put a file to a remote FTP site. Raises a build error this operation
      # fails. Parameter is a hash with following entries:
      #
      # - username: the username to connect to FTP. Defaults to anonymous.
      # - password: the password to connect to FTP. Defaults to no password.
      # - host: the hostname to connect to.
      # - file: locale file to send.
      # - tofile: remote file to write on remote server. Defaults to base name
      #   of local file.
      # - binary: sets the binary mode for upload. Defaults to true.
      #
      # Example:
      #
      #   - ftp_put:
      #       username: foo
      #       password: bar
      #       host: foo
      #       file: test.txt
      def ftp_put(params)
        params_desc = {
          :username => { :mandatory => false, :type => :string },
          :password => { :mandatory => false, :type => :string },
          :host     => { :mandatory => true,  :type => :string },
          :file     => { :mandatory => true,  :type => :string },
          :tofile   => { :mandatory => false, :type => :string },
          :binary   => { :mandatory => false, :type => :boolean,
                         :default   => true }
        }
        check_parameters(params, params_desc)
        username = params[:username]
        password = params[:password]
        host     = params[:host]
        file     = params[:file]
        tofile   = params[:tofile]
        binary   = params[:binary]
        basename = File.basename(file)
        puts "Putting file '#{basename}'..."
        begin
          Net::FTP.open(host) do |ftp|
            ftp.login(username, password)
            if binary
              ftp.putbinaryfile(file, tofile)
            else
              ftp.puttextfile(file, tofile)
            end
            ftp.close
          end
        rescue Exception
          error "Error putting file '#{basename}': #{$!}"
        end
      end

      # Make a directory on a remote FTP site. Raises a build error this
      # operation fails. Parameter is a hash with following entries:
      #
      # - username: the username to connect to FTP. Defaults to anonymous.
      # - password: the password to connect to FTP. Defaults to no password.
      # - host: the hostname to connect to.
      # - dir: the path of the remote directory to create.
      #
      # Example:
      #
      #   - ftp_mkdir:
      #       username: foo
      #       password: bar
      #       host: foo
      #       dir:  test
      def ftp_mkdir(params)
        params_desc = {
          :username  => { :mandatory => false, :type => :string },
          :password  => { :mandatory => false, :type => :string },
          :host      => { :mandatory => true,  :type => :string },
          :dir       => { :mandatory => true,  :type => :string }
        }
        check_parameters(params, params_desc)
        username  = params[:username]
        password  = params[:password]
        host      = params[:host]
        dir       = params[:dir]
        basename  = File.basename(dir)
        puts "Making directory '#{basename}'..."
        begin
          Net::FTP.open(host) do |ftp|
            ftp.login(username, password)
            ftp.mkdir(dir)
            ftp.close
          end
        rescue Exception
          error "Error making directory '#{basename}': #{$!}"
        end
      end

      ######################################################################
      #                             CONSTRUCTS                             #
      ######################################################################
    
      # If construct will evaluate the expression in the 'if' entry and run
      # block in the 'then' entry or 'else' entry accordingly.
      #
      # - if: the condition to evaluate. This is a Ruby expression (thus a 
      #   string) evaluated in the build context, a symbol that refers to a
      #   property or a boolean.
      # - then: block that is evaluated if condition in if is true.
      # - else: block that is evaluated if condition in if is false.
      #
      # Example
      #
      #   - if: RUBY_PLATFORM =~ /darwin/
      #     then:
      #     - print: Hello, I'm a Mac
      #     else:
      #     - print: Hello, I'm a PC
      def if
      end

      # While construct will run the block in the 'do' entry while the
      # condition in the 'while' entry is true.
      #
      # - while: the condition to evaluate. This is a Ruby expression evaluated
      #   in the build context.
      # - do: the block to run while the condition is true.
      #
      # Example:
      #
      #   - while: i > 0
      #     do:
      #     - print: :i
      #     - rb: i -= 1
      def while
      end

      # For construct iterates on a list in the 'in' entry, putting values in
      # a property which name is in the 'for' entry and running the block in
      # the 'do' entry for each value.
      #
      # - for: the name of the property which receives values of the iteration,
      #   as a string.
      # - in: a list on which to iterate. This can be a list, a ruby expression
      #   to evaluate in the context of the build to obtain the Enumerable on
      #   which to iterate or a symbol that refers to a property that is a list.
      # - do: the block to run at each iteration.
      #
      # Example
      #
      #   - for: file
      #     in:  [foo, bar]
      #     do:
      #       - print: "Creating #{file}..."
      #       - touch: :file
      #
      # The same using a reference to a property that is a list:
      #
      #   - properties:
      #       list: ['foo', 'bar']
      #
      #   - target: test
      #     script:
      #     - for: name
      #       in:  :list
      #       do:
      #       - print: "Hi #{name}!"
      #
      # To iterate five times, we could write (using a Ruby Range):
      #
      #   - for: i
      #     in:  (1..5)
      #     do:
      #       - print: :i
      #
      # To iterate on files in current directory, we could write:
      #
      #   - for: file
      #     in:  "Dir.glob('*')"
      #     do:
      #       - print: :file
      def for
      end

      # Try construct will run the block in the 'try' entry and will switch to
      # block in the 'catch' entry if an error occurs.
      #
      # - try: the block to run.
      # - catch: the block to switch to if an error occurs.
      #
      # Example:
      #
      #   - try:
      #     - print: "In the try block"
      #     - throw: "Something went terribly wrong!"
      #     catch:
      #     - print: "An error occured"
      def try
      end

    end

  end

end

