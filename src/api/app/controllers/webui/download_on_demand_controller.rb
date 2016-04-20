class Webui::DownloadOnDemandController < Webui::WebuiController
  before_filter :set_project

  def create
    @download_on_demand = DownloadRepository.new(permitted_params)
    authorize @download_on_demand

    # Workaround: We need this association to pass the DownloadRepository validation.
    #             If something in the transaction goes wrong, we have to destroy the object again.
    repository_arch = nil
    unless @download_on_demand.repository.architectures.pluck(:name).include?(permitted_params[:arch])
      repository_arch = RepositoryArchitecture.create(
        repository:   @download_on_demand.repository,
        architecture: Architecture.find_by_name(permitted_params[:arch])
      )
    end

    begin
      ActiveRecord::Base.transaction do
        @download_on_demand.save!
        @project.store
      end
    rescue ActiveRecord::RecordInvalid, ActiveXML::Transport::Error => exception
      repository_arch.destroy if repository_arch
      redirect_to :back, error: "Download on Demand can't be created: #{exception.message}"
      return
    end

    redirect_to project_repositories_path(@project), notice: "Successfully created Download on Demand"
  end

  def update
    @download_on_demand = DownloadRepository.find(params[:id])
    authorize @download_on_demand

    begin
      ActiveRecord::Base.transaction do
        # FIXME: Handle changing architecture or permit it
        @download_on_demand.update_attributes!(permitted_params)
        @project.store
      end
    rescue ActiveRecord::RecordInvalid, ActiveXML::Transport::Error => exception
      redirect_to :back, error: "Download on Demand can't be updated: #{exception.message}"
      return
    end

    redirect_to project_repositories_path(@project), notice: "Successfully updated Download on Demand"
  end

  def destroy
    @download_on_demand = DownloadRepository.find(params[:id])
    authorize @download_on_demand

    if @download_on_demand.repository.download_repositories.count <= 1
      redirect_to :back, error: "Download on Demand can't be removed: DoD Repositories must have at least one repository."
      return
    end

    begin
      ActiveRecord::Base.transaction do
        # FIXME: should remove repo arch?
        @download_on_demand.destroy!
        @project.store
      end
    rescue ActiveRecord::RecordInvalid, ActiveXML::Transport::Error => exception
      redirect_to :back, error: "Download on Demand can't be removed: #{exception.message}"
      return
    end

    redirect_to project_repositories_path(@project), notice: "Successfully removed Download on Demand"
  end

  private

  def permitted_params
    params.require(:download_repository).permit(:arch, :repotype, :url, :repository_id, :archfilter, :masterurl, :mastersslfingerprint, :pubkey)
  end
end
