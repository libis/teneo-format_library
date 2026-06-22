# frozen_string_literal: true

workers 0
port 3000
activate_control_app 'tcp://0.0.0.0:3001', { no_token: true }
