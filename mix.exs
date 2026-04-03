defmodule AbsintheUploadStandard.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/Leandro-Moreno/absinthe_upload_standard"

  def project do
    [
      app: :absinthe_upload_standard,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      source_url: @source_url
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:plug, "~> 1.14"},
      {:jason, "~> 1.4"},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false}
    ]
  end

  defp description do
    """
    Standard graphql-multipart-request-spec support for Absinthe uploads.
    Built by the Shiko team. Transitional package while absinthe_plug#309
    gets merged upstream.
    """
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Upstream PR" => "https://github.com/absinthe-graphql/absinthe_plug/pull/309",
        "graphql-multipart-request-spec" =>
          "https://github.com/jaydenseric/graphql-multipart-request-spec"
      }
    ]
  end
end
