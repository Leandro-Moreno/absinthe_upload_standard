defmodule AbsintheUploadStandard do
  @moduledoc """
  A Plug that transforms requests following the
  [graphql-multipart-request-spec](https://github.com/jaydenseric/graphql-multipart-request-spec)
  into the format that Absinthe expects.

  This allows standard GraphQL clients (Apollo Client, urql, Relay, Flutter, etc.)
  to upload files through Absinthe without any custom client-side upload links.

  > **Note:** This package is a transitional solution while
  > [absinthe_plug#309](https://github.com/absinthe-graphql/absinthe_plug/pull/309)
  > gets reviewed and merged upstream. Once `absinthe_plug` natively supports the
  > standard spec, this package will no longer be necessary. We'll mark it as
  > deprecated at that point.

  ## Usage

  Add it to your router pipeline **before** `Absinthe.Plug`:

      plug Plug.Parsers,
        parsers: [:urlencoded, :multipart, :json, Absinthe.Plug.Parser],
        pass: ["*/*"],
        json_decoder: Jason

      plug AbsintheUploadStandard

      forward "/graphql",
        to: Absinthe.Plug,
        init_opts: [schema: MyApp.Schema]

  ## How it works

  The standard spec sends uploads as:

      operations: {"query": "mutation($file: Upload!) {...}", "variables": {"file": null}}
      map: {"0": ["variables.file"]}
      0: <the actual file>

  This plug rewrites the request into Absinthe's native format by replacing
  the `null` variable placeholders with string references to the form field names.
  The existing `:upload` scalar then resolves them as usual.

  Requests that don't include `operations` + `map` fields pass through unchanged,
  so Absinthe's custom upload format keeps working.
  """

  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(%{body_params: %{"operations" => operations, "map" => map_json}} = conn, _opts) do
    json_codec = Application.get_env(:absinthe_upload_standard, :json_codec, Jason)

    with {:ok, ops} <- json_codec.decode(operations),
         {:ok, file_map} <- json_codec.decode(map_json) do
      transform_request(conn, ops, file_map)
    else
      {:error, _} -> conn
    end
  end

  def call(conn, _opts), do: conn

  defp transform_request(conn, ops, file_map) when is_list(ops) do
    json_list =
      ops
      |> Enum.with_index()
      |> Enum.map(fn {op, idx} ->
        batch_file_map =
          file_map
          |> Enum.filter(fn {_field, paths} ->
            Enum.any?(paths, &String.starts_with?(&1, "#{idx}."))
          end)
          |> Enum.map(fn {field, paths} ->
            {field, Enum.map(paths, &String.replace_prefix(&1, "#{idx}.", ""))}
          end)
          |> Map.new()

        build_query_params(op, batch_file_map)
      end)

    params =
      conn.params
      |> Map.put("_json", json_list)
      |> Map.delete("operations")
      |> Map.delete("map")

    %{conn | params: params, body_params: params}
  end

  defp transform_request(conn, ops, file_map) do
    query_params = build_query_params(ops, file_map)

    params =
      conn.params
      |> Map.merge(query_params)
      |> Map.delete("operations")
      |> Map.delete("map")

    %{conn | params: params, body_params: params}
  end

  defp build_query_params(ops, file_map) do
    variables = apply_file_map(ops["variables"] || %{}, file_map)

    %{
      "query" => ops["query"],
      "variables" => variables,
      "operationName" => ops["operationName"]
    }
  end

  defp apply_file_map(variables, file_map) do
    Enum.reduce(file_map, variables, fn {field_name, paths}, vars ->
      Enum.reduce(paths, vars, fn path, v ->
        keys = path |> String.replace_prefix("variables.", "") |> String.split(".")
        deep_put(v, keys, field_name)
      end)
    end)
  end

  defp deep_put(map, [key], value) when is_map(map), do: Map.put(map, key, value)

  defp deep_put(list, [index], value) when is_list(list) do
    List.replace_at(list, String.to_integer(index), value)
  end

  defp deep_put(map, [key | rest], value) when is_map(map) do
    Map.update(map, key, deep_put(%{}, rest, value), &deep_put(&1, rest, value))
  end

  defp deep_put(list, [index | rest], value) when is_list(list) do
    List.update_at(list, String.to_integer(index), &deep_put(&1, rest, value))
  end
end
