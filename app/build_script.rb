require "digest"
require "shellwords"

module Tint
	def self.build_script(job_id, site_id, remote)
		job_id = Shellwords.escape(job_id.to_s)
		site_id = Shellwords.escape(site_id.to_s)
		remote = Shellwords.escape(remote.to_s)
		app_url = Shellwords.escape(ENV.fetch("APP_URL"))

		prefix = "/tmp/#{job_id}"
		clone = "/tmp/#{job_id}-clone"
		tar = "#{job_id}.tar"

		<<-SCRIPT
		#!/bin/sh

		set -e

		rm -rf #{clone} #{prefix}
		mkdir -p #{prefix}
		git clone --depth=1 #{remote} #{clone}
		cd #{clone}

		make PREFIX=#{prefix}
		make install PREFIX=#{prefix}

		cd /tmp
		tar --posix --one-file-system --owner=33 --group=33 \\
			-cf #{tar} #{job_id}/
		curl -u #{job_id}:#{Tint.token(job_id)} \\
			#{app_url}/#{site_id}/deploy \\
			--data-binary @#{tar}

		rm -rf #{tar} #{prefix} #{clone}
		SCRIPT
	end

	def self.token(x)
		Digest::SHA256.hexdigest("#{x}#{ENV.fetch('SESSION_SECRET')}#{x}")
	end
end
