defmodule CaeNew.Vault do
  @moduledoc """
  Cloak vault for encrypting sensitive medical data.

  This vault uses AES encryption with a configuration key stored in environment variables
  or configuration files. For production, ensure the key is securely stored.
  """

  use Cloak.Vault, otp_app: :cae_new
end
