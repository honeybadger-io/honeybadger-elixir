defmodule Honeybadger.NoticeFilter.Default do
  @behaviour Honeybadger.NoticeFilter

  def filter(%Honeybadger.Notice{} = notice) do
    if filter = Honeybadger.get_env(:filter) do
      notice
      |> Map.put(:request, filter_request(notice.request, filter))
      |> Map.put(:error, filter_error(notice.error, filter))
    else
      notice
    end
  end

  defp filter_request(request, filter) do
    request
    |> apply_filter(:context, &filter.filter_context/1)
    |> apply_filter(:params, &filter.filter_params/1)
    |> apply_filter(:cgi_data, &filter.filter_cgi_data/1)
    |> apply_filter(:session, &filter.filter_session/1)
    |> disable(:filter_disable_url, :url)
    |> disable(:filter_disable_session, :session)
    |> disable(:filter_disable_params, :params)
  end

  defp apply_filter(request, key, filter_fn) do
    case Map.get(request, key) do
      nil -> request
      target -> Map.put(request, key, filter_fn.(target))
    end
  end

  defp filter_error(%{message: message} = error, filter) do
    error
    |> Map.put(:message, filter.filter_error_message(message))
  end

  defp disable(request, config_key, map_key) do
    if Honeybadger.get_env(config_key) do
      Map.drop(request, [map_key])
    else
      request
    end
  end
end
