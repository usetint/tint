unless {}.respond_to?(:dig)
	class Hash
		def dig(*args)
			args.reduce(self) do |h, k|
				h && h[k]
			end
		end
	end
end
