defmodule Honeybadger.NoticeFilter.Default do
  @behaviour Honeybadger.NoticeFilter

  @cgi_disable_url_filters ~w(original_fullpath query_string path_info)

  def filter(%Honeybadger.Notice{} = notice) do
    if filter = Honeybadger.get_env(:filter) do
      notice
      |> Map.put(:request, filter_request(notice.request, filter))
      |> Map.put(:error, filter_error(notice.error, filter))
      |> Map.put(:breadcrumbs, filter_breadcrumbs(notice.breadcrumbs, filter))
    else
      notice
    end
  end

  defp filter_request(request, filter) do
    request
    |> apply_filter(:context, &filter.filter_context/1)
    |> apply_filter(:params, &filter.filter_params/1)
    |> apply_filter(:cgi_data, &filter_cgi_data/1)
    |> apply_filter(:session, &filter.filter_session/1)
    |> disable(:filter_disable_url, :url)
    |> disable(:filter_disable_session, :session)
    |> disable(:filter_disable_params, :params)
  end

  defp filter_error(%{message: message} = error, filter) do
    Map.put(error, :message, filter.filter_error_message(message))
  end

  defp filter_breadcrumbs(breadcrumbs, filter) do
    Map.update(breadcrumbs, :trail, %{}, &filter.filter_breadcrumbs/1)
  end

  defp apply_filter(request, key, filter_fn) do
    case Map.get(request, key) do
      nil -> request
      target -> Map.put(request, key, filter_fn.(target))
    end
  end

  defp filter_cgi_data(map) do
    filter = Honeybadger.get_env(:filter)

    filter.filter_map(map, cgi_filter_keys())
  end

  defp cgi_filter_keys do
    filter_keys = Honeybadger.get_env(:filter_keys)

    if Honeybadger.get_env(:filter_disable_url) do
      filter_keys ++ @cgi_disable_url_filters
    else
      filter_keys
    end
  end

  defp disable(request, config_key, map_key) do
    if Honeybadger.get_env(config_key) do
      Map.drop(request, [map_key])
    else
      request
    end
  end
end
