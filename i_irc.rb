require 'rubygems'
require 'eventmachine'
require 'socket'

class IRC
  def initialize(opts = {})
    @server  = opts[:server]
    @port    = opts[:port]
    @nick    = opts[:nick]
    @user    = opts[:user]
    @name    = opts[:name]
    @channel = opts[:channel]
    @bridge  = opts[:bridge]
    @connected = false
  end

  def connected?
    @connected
  end

  def connect
    @socket = TCPSocket.open(@server, @port)
    @connected = true
    send "USER #{@user} 0 * :#{@name}"
    send "NICK #{@nick}"
    send "JOIN #{@channel}"
  end

  def send(msg)
    @socket.puts msg 
  end

  def say_to_chan(msg)
    send "PRIVMSG #{@channel} :#{msg}"
  end

  def run
    until @socket.eof? do
      msg = @socket.gets

      if msg.match(/^PING :(.*)$/)
        send "PONG #{$~[1]}"
        next
      end

      if msg.match(/^:(.+?)!.+?@.+?\sPRIVMSG.*(\#.*)\:(.*)/i)
        nick    = $~[1].strip
        channel = $~[2].strip
        text    = $~[3].strip

        if channel == @channel
          @bridge.add([nick, text], :jabber)
          puts "Sent a message to the Jabber queue [#{nick}, #{text}]"
        end
      end
      sleep 0.1
    end
  end

  def quit
    say "PART ##{@channel} :#{@nick}, Hell with this"
    say 'QUIT'
  end
end

class IIrc
  def self.start(config, bridge)
    @bot = IRC.new(
      :server  => config[:server],
      :port    => config[:port],
      :nick    => config[:nick],
      :user    => config[:user],
      :name    => config[:name],
      :channel => config[:channel],
      :bridge  => bridge
    )

    EM::run do
      EM::PeriodicTimer.new(0.1) do
        if @bot.connected? && item = bridge.shift(:irc)
          user, msg = item
          puts "Received a message from the IRC queue: #{item.inspect}"
          @bot.say_to_chan("[#{user}]: #{msg}")
        end
      end
    
      @bot.connect
      @bot.run
    end
  end
end
