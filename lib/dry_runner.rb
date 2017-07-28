module DryRunner
  def dry_runner(collection, proc, msg_proc)
    collection.each do |item|
      begin
        if @dry_run
          puts "DRY-RUN: #{msg_proc.call(item)}"
        else
          puts msg_proc.call(item)
          proc.call(item)
        end
      rescue => e
        puts "ERROR: #{e.message}"
      end
    end
  end
end
