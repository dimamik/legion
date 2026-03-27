defmodule Legion.AgentServerTest do
  use ExUnit.Case, async: false
  use Mimic

  alias Legion.Test.Support.MathAgent
  alias ReqLLM.Message.ContentPart

  setup :set_mimic_global

  @moduletag capture_log: true

  defp llm_response(result) do
    {:ok,
     %ReqLLM.Response{
       id: "test",
       model: "test",
       context: nil,
       object: %{"action" => "return", "code" => "", "result" => result}
     }}
  end

  describe "image messages" do
    test "sends {:image, data, media_type} as a content parts list to the LLM" do
      test_pid = self()
      image_data = <<0xFF, 0xD8, 0xFF, 0xE0>>

      stub(ReqLLM, :generate_object, fn _model, messages, _schema ->
        user_msg = Enum.find(messages, &(&1[:role] == "user"))
        send(test_pid, {:user_content, user_msg[:content]})
        llm_response("ok")
      end)

      assert {:ok, "ok"} = Legion.execute(MathAgent, {:image, image_data, "image/jpeg"})

      assert_received {:user_content, content}

      assert [
               %ContentPart{
                 type: :image,
                 media_type: "image/jpeg",
                 data: ^image_data
               }
             ] = content
    end

    test "sends {:image_url, url} as a content parts list to the LLM" do
      test_pid = self()

      stub(ReqLLM, :generate_object, fn _model, messages, _schema ->
        user_msg = Enum.find(messages, &(&1[:role] == "user"))
        send(test_pid, {:user_content, user_msg[:content]})
        llm_response("ok")
      end)

      assert {:ok, "ok"} =
               Legion.execute(MathAgent, {:image_url, "https://example.com/photo.png"})

      assert_received {:user_content, content}

      assert [%ContentPart{type: :image_url, url: "https://example.com/photo.png"}] =
               content
    end

    test "sends {:multipart, parts} as-is to the LLM" do
      test_pid = self()

      parts = [
        ContentPart.text("Describe this image."),
        ContentPart.image(<<1, 2, 3>>, "image/png")
      ]

      stub(ReqLLM, :generate_object, fn _model, messages, _schema ->
        user_msg = Enum.find(messages, &(&1[:role] == "user"))
        send(test_pid, {:user_content, user_msg[:content]})
        llm_response("ok")
      end)

      assert {:ok, "ok"} = Legion.execute(MathAgent, {:multipart, parts})

      assert_received {:user_content, ^parts}
    end
  end
end
