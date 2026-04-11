defmodule Legion.AgentServerTest do
  use ExUnit.Case, async: false
  use Mimic

  import ExUnit.CaptureLog

  alias Legion.Test.Support.MathAgent
  alias ReqLLM.Message.ContentPart

  defmodule SharedBindingsAgent do
    @moduledoc "Agent with shared bindings."
    use Legion.Agent

    def config, do: %{share_bindings: true}
  end

  defmodule ConfiguredAgent do
    @moduledoc "Test agent with custom config."
    use Legion.Agent

    def config, do: %{model: "agent-model"}
    def tools, do: [Legion.Test.Support.MathTool]
  end

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

  defp llm_eval_response(code) do
    {:ok,
     %ReqLLM.Response{
       id: "test",
       model: "test",
       context: nil,
       object: %{"action" => "eval_and_complete", "code" => code, "result" => ""}
     }}
  end

  describe "get_messages/1" do
    test "returns conversation history from a running agent" do
      stub(ReqLLM, :generate_object, fn _model, _messages, _schema ->
        llm_response("Paris")
      end)

      {:ok, pid} = Legion.start_link(MathAgent)
      {:ok, _} = Legion.call(pid, "What is the capital of France?")

      messages = Legion.get_messages(pid)

      assert [
               %{role: "system", content: _system},
               %{role: "user", content: "What is the capital of France?"},
               %{role: "assistant"} | _
             ] = messages
    end
  end

  describe "config validation" do
    test "warns about unknown config keys" do
      stub(ReqLLM, :generate_object, fn _model, _messages, _schema ->
        llm_response("ok")
      end)

      log =
        capture_log(fn ->
          {:ok, pid} = Legion.start_link(MathAgent, bogus_key: true)
          {:ok, _} = Legion.call(pid, "hi")
        end)

      assert log =~ "Unknown Legion config keys: [:bogus_key]"
    end
  end

  describe "config resolution" do
    test "call-time opts override agent config" do
      test_pid = self()

      stub(ReqLLM, :generate_object, fn model, _messages, _schema ->
        send(test_pid, {:model_used, model})
        llm_response("ok")
      end)

      {:ok, pid} = Legion.start_link(ConfiguredAgent, model: "call-model")
      {:ok, _} = Legion.call(pid, "hi")

      assert_receive {:model_used, "call-model"}
    end

    test "agent config overrides application config" do
      Application.put_env(:legion, :config, %{model: "app-model"})

      on_exit(fn -> Application.delete_env(:legion, :config) end)

      test_pid = self()

      stub(ReqLLM, :generate_object, fn model, _messages, _schema ->
        send(test_pid, {:model_used, model})
        llm_response("ok")
      end)

      {:ok, pid} = Legion.start_link(ConfiguredAgent)
      {:ok, _} = Legion.call(pid, "hi")

      assert_receive {:model_used, "agent-model"}
    end
  end

  describe "terminate/2" do
    test "emits stopped event when agent terminates" do
      stub(ReqLLM, :generate_object, fn _, _, _ -> llm_response("ok") end)

      test_pid = self()
      handler_id = "test-terminate-#{System.unique_integer()}"

      :telemetry.attach(
        handler_id,
        [:legion, :agent, :stopped],
        fn _event, _measurements, metadata, _ ->
          send(test_pid, {:stopped, metadata.agent})
        end,
        nil
      )

      {:ok, pid} = Legion.start_link(MathAgent)
      GenServer.stop(pid)

      assert_receive {:stopped, Legion.Test.Support.MathAgent}
      :telemetry.detach(handler_id)
    end
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

  describe "cast/2" do
    test "processes message and updates state without blocking" do
      stub(ReqLLM, :generate_object, fn _model, _messages, _schema ->
        llm_response("Paris")
      end)

      {:ok, pid} = Legion.start_link(MathAgent)
      assert :ok = Legion.cast(pid, "What is the capital of France?")

      Process.sleep(100)

      messages = Legion.get_messages(pid)

      assert [
               %{role: "system"},
               %{role: "user", content: "What is the capital of France?"},
               %{role: "assistant"} | _
             ] = messages
    end
  end

  describe "named registration" do
    test "agent can be started with a registered name" do
      stub(ReqLLM, :generate_object, fn _model, _messages, _schema ->
        llm_response("42")
      end)

      {:ok, _pid} = Legion.start_link(MathAgent, name: :test_named_agent)
      assert {:ok, "42"} = Legion.call(:test_named_agent, "What is 42?")
    end
  end

  describe "share_bindings" do
    test "bindings do not persist across turns by default" do
      stub(ReqLLM, :generate_object, fn _model, messages, _schema ->
        assistant_count = Enum.count(messages, &(&1[:role] == "assistant"))

        if assistant_count == 0 do
          llm_eval_response("x = 42")
        else
          llm_eval_response("x + 1")
        end
      end)

      {:ok, pid} = Legion.start_link(MathAgent)
      {:ok, 42} = Legion.call(pid, "set x")

      ExUnit.CaptureIO.capture_io(:stderr, fn ->
        assert {:cancel, :reached_max_retries} = Legion.call(pid, "use x")
      end)
    end

    test "bindings persist across turns when share_bindings is true" do
      stub(ReqLLM, :generate_object, fn _model, messages, _schema ->
        assistant_count = Enum.count(messages, &(&1[:role] == "assistant"))

        if assistant_count == 0 do
          llm_eval_response("x = 42")
        else
          llm_eval_response("x + 1")
        end
      end)

      {:ok, pid} = Legion.start_link(SharedBindingsAgent)
      {:ok, 42} = Legion.call(pid, "set x")
      assert {:ok, 43} = Legion.call(pid, "use x")
    end
  end
end
