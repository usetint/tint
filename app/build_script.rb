require "digest"
require "shellwords"

module Tint
	def self.build_script(job_id, site_id, remote, token, ssh_private_key=nil)
		job_id = Shellwords.escape(job_id.to_s)
		site_id = Shellwords.escape(site_id.to_s)
		remote = Shellwords.escape(remote.to_s)
		app_url = Shellwords.escape(ENV.fetch("APP_URL"))

		prefix = "/tmp/#{job_id}"
		clone = "/tmp/#{job_id}-clone"
		tar = "#{job_id}.tar"

		if ssh_private_key
			ssh_private_key = <<-KEY
			mkdir -p ~/.ssh
			chmod 0700 ~/.ssh
			printf "%s" #{Shellwords.escape(ssh_private_key)} > ~/.ssh/id_ed25519
			chmod 0600 ~/.ssh/id_ed25519
			KEY
		end

		<<-SCRIPT
		#!/bin/sh

		set -e

		#{ssh_private_key}

		rm -rf #{clone} #{prefix}
		mkdir -p #{prefix}
		git clone --depth=1 --no-single-branch #{remote} #{clone}
		git annex get || true # Get from annex if there is one
		cd #{clone}

		make PREFIX=#{prefix}
		make install PREFIX=#{prefix}

		cd /tmp
		tar --posix --one-file-system --owner=33 --group=33 \\
			-cf #{tar} #{job_id}/
		curl -u #{job_id}:#{token} \\
			#{app_url}/#{site_id}/deploy \\
			--data-binary @#{tar}

		rm -rf #{tar} #{prefix} #{clone}
		SCRIPT
	end

	def self.token(x)
		Digest::SHA256.hexdigest("#{x}#{ENV.fetch('SESSION_SECRET')}#{x}")
	end
end
