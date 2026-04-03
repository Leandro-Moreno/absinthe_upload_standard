defmodule AbsintheUploadStandardTest do
  use ExUnit.Case
  use Plug.Test

  describe "standard multipart spec requests" do
    test "transforms single file upload" do
      upload = %Plug.Upload{path: "/tmp/test", filename: "test.jpg", content_type: "image/jpeg"}

      operations =
        Jason.encode!(%{
          query: "mutation($file: Upload!) { upload(file: $file) { url } }",
          variables: %{file: nil}
        })

      map = Jason.encode!(%{"0" => ["variables.file"]})

      conn =
        conn(:post, "/graphql", %{
          "operations" => operations,
          "map" => map,
          "0" => upload
        })
        |> put_req_header("content-type", "multipart/form-data")
        |> AbsintheUploadStandard.call([])

      assert conn.params["query"] =~ "mutation"
      assert conn.params["variables"]["file"] == "0"
      assert conn.params["0"] == upload
      refute Map.has_key?(conn.params, "operations")
      refute Map.has_key?(conn.params, "map")
    end

    test "transforms multiple file uploads" do
      upload_a = %Plug.Upload{path: "/tmp/a", filename: "a.jpg", content_type: "image/jpeg"}
      upload_b = %Plug.Upload{path: "/tmp/b", filename: "b.png", content_type: "image/png"}

      operations =
        Jason.encode!(%{
          query: "mutation($a: Upload!, $b: Upload!) { upload(a: $a, b: $b) { url } }",
          variables: %{a: nil, b: nil}
        })

      map = Jason.encode!(%{"0" => ["variables.a"], "1" => ["variables.b"]})

      conn =
        conn(:post, "/graphql", %{
          "operations" => operations,
          "map" => map,
          "0" => upload_a,
          "1" => upload_b
        })
        |> put_req_header("content-type", "multipart/form-data")
        |> AbsintheUploadStandard.call([])

      assert conn.params["variables"]["a"] == "0"
      assert conn.params["variables"]["b"] == "1"
    end

    test "handles nested array paths" do
      upload = %Plug.Upload{path: "/tmp/test", filename: "test.jpg", content_type: "image/jpeg"}

      operations =
        Jason.encode!(%{
          query: "mutation($files: [Upload!]!) { upload(files: $files) { url } }",
          variables: %{files: [nil]}
        })

      map = Jason.encode!(%{"0" => ["variables.files.0"]})

      conn =
        conn(:post, "/graphql", %{
          "operations" => operations,
          "map" => map,
          "0" => upload
        })
        |> put_req_header("content-type", "multipart/form-data")
        |> AbsintheUploadStandard.call([])

      assert conn.params["variables"]["files"] == ["0"]
    end

    test "passes through non-upload requests unchanged" do
      conn =
        conn(:post, "/graphql", %{
          "query" => "{ hello }",
          "variables" => %{}
        })
        |> put_req_header("content-type", "application/json")
        |> AbsintheUploadStandard.call([])

      assert conn.params["query"] == "{ hello }"
    end

    test "passes through invalid JSON gracefully" do
      conn =
        conn(:post, "/graphql", %{
          "operations" => "not json",
          "map" => "also not json"
        })
        |> put_req_header("content-type", "multipart/form-data")
        |> AbsintheUploadStandard.call([])

      # Should pass through unchanged
      assert conn.params["operations"] == "not json"
    end
  end
end
