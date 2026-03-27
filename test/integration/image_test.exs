defmodule Legion.Integration.ImageTest do
  @moduledoc """
  Integration test: send an image to a vision-capable model.

  Run with:

      mix test test/integration/image_test.exs --include integration
  """
  use ExUnit.Case, async: false

  alias ReqLLM.Message.ContentPart

  @moduletag :integration
  @moduletag timeout: 60_000

  defmodule ImageAgent do
    @moduledoc "Describes what is in an image."
    use Legion.Agent

    def config, do: %{model: "openai:gpt-4o-mini"}
  end

  setup do
    unless System.get_env("OPENAI_API_KEY"), do: raise("OPENAI_API_KEY not set")
    :ok
  end

  test "describes an image sent as binary data" do
    # 1x1 red pixel PNG
    red_pixel_png =
      Base.decode64!(
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC"
      )

    msg =
      {:multipart,
       [
         ContentPart.text("Describe what you see in this image in one sentence."),
         ContentPart.image(red_pixel_png, "image/png")
       ]}

    {:ok, result} = Legion.execute(ImageAgent, msg)

    assert is_binary(result)
    assert String.downcase(result) =~ "red"
  end
end
