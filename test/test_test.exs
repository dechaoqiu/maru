defmodule Maru.TestTest do
  use ExUnit.Case, async: true

  test "test" do
    defmodule Test1 do
      use Maru.Router
      version "v3"

      get do
        text(conn, "resp")
      end
    end

    defmodule TestTest1 do
      use Maru.Test, for: Maru.TestTest.Test1

      def test do
        get("/") |> text_response
      end
    end

    assert "resp" = TestTest1.test
  end

  test "version test" do
    defmodule Test2 do
      use Maru.Router

      version "v1" do
        get do
          text(conn, "resp v1")
        end
      end

      version "v2" do
        get do
          text(conn, "resp v2")
        end
      end
    end

    defmodule TestTest2 do
      use Maru.Test, for: Maru.TestTest.Test2

      def test1 do
        get("/", "v1") |> text_response
      end

      def test2 do
        get("/", "v2") |> text_response
      end
    end

    assert "resp v1" = TestTest2.test1
    assert "resp v2" = TestTest2.test2
  end

  test "parser test" do
    defmodule Test3 do
      use Maru.Router

      params do
        requires :foo
      end
      post do
        json(conn, params)
      end
    end

    defmodule TestTest3 do
      use Maru.Test, for: Maru.TestTest.Test3

      def test do
        opts = [
          parsers: [Plug.Parsers.URLENCODED, Plug.Parsers.JSON, Plug.Parsers.MULTIPART],
          pass: ["*/*"],
          json_decoder: Poison
        ]

        build_conn()
        |> Plug.Conn.put_req_header("content-type", "application/json")
        |> put_body_or_params(~s({"foo":"bar"}))
        |> put_plug(Plug.Parsers, opts)
        |> post("/")
        |> json_response
      end
    end

    assert %{"foo" => "bar"} = TestTest3.test
  end

  test "mounted" do
    defmodule PlugTest do
      def init([]), do: []
      def call(conn, []) do
        conn |> Plug.Conn.put_private(:maru_plug_test, 0)
      end
    end

    defmodule PlugTest1 do
      def init([]), do: []
      def call(conn, []) do
        conn |> Plug.Conn.put_private(:maru_plug_test1, 0)
      end
    end

    defmodule TestMount do
      use Maru.Router

      plug Maru.TestTest.PlugTest

      mount Maru.TestTest.TestMount1
      mount Maru.TestTest.TestMount2
    end

    defmodule TestMount1 do
      use Maru.Router

      plug Maru.TestTest.PlugTest1

      namespace :m1 do
        get do
          text(conn, "m1")
        end
        mount Maru.TestTest.TestMountShared
      end
    end

    defmodule TestMount2 do
      use Maru.Router

      namespace :m2 do
        get do
          text(conn, "m2")
        end
        mount Maru.TestTest.TestMountShared
      end
    end

    defmodule TestMountShared do
      use Maru.Router

      get :shared do
        text(conn, "shared")
      end
    end

    for module <- [Maru.TestTest.TestMount, Maru.TestTest.TestMount1, Maru.TestTest.TestMount2, Maru.TestTest.TestMountShared] do
      Enum.each(module.__mounted_modules__, fn mounted ->
        Maru.Builder.MountLink.put_father(mounted, module)
      end)
    end

    defmodule TestMountTest do
      use Maru.Test, for: Maru.TestTest.TestMount1 |> Maru.TestTest.TestMountShared
      def test, do: get("shared")
    end

    defmodule TestMountTest2 do
      use Maru.Test, for: Maru.TestTest.TestMount2 |> Maru.TestTest.TestMountShared
      def test, do: get("shared")
    end

    private1 = TestMountTest.test().private
    assert 0 == private1.maru_plug_test
    assert 0 == private1.maru_plug_test1

    private2 = TestMountTest2.test().private
    assert 0 == private2.maru_plug_test
    assert false == Map.has_key?(private2, :maru_plug_test1)

  end

  test "mounted overridable" do
    defmodule PlugTest2 do
      def init([]), do: []
      def call(conn, []) do
        conn |> Plug.Conn.put_private(:maru_plug_test2, 0)
      end
    end

    defmodule PlugTest3 do
      def init([]), do: []
      def call(conn, []) do
        conn |> Plug.Conn.put_private(:maru_plug_test3, 0)
      end
    end

    defmodule MountedOverriable do
      use Maru.Router
      plug_overridable :test, Maru.TestTest.PlugTest2
      mount Maru.TestTest.MountedOverriableShared
    end

    defmodule MountedOverriableShared do
      use Maru.Router

      pipeline do
        plug_overridable :test, Maru.TestTest.PlugTest3
      end
      get :shared do
        text(conn, "shared")
      end
    end

    defmodule MountedOverriableSharedTest do
      use Maru.Test, for: Maru.TestTest.MountedOverriableShared
      def test, do: get("shared")
    end

    private = MountedOverriableSharedTest.test().private
    assert 0 == private.maru_plug_test3
    assert false == Map.has_key?(private, :maru_plug_test2)
  end

end
